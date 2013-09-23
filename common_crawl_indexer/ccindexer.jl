using TextAnalysis
using Stemmers
using Blocks
using HDFS
using Base.FS
using HTTPClient
using AWS
using AWS.S3
using GZip


##
# Configurable constants
######################################################
## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc")
const docs_location         = joinpath(fs_pfx, "docs")

const ndocs_per_idx_part    = 6000

_next_doc_id = 1
function allocate_docids(n)
    global _next_doc_id
    docids = _next_doc_id:(_next_doc_id+n-1)
    _next_doc_id += n
    docids
end

function assign_docids(crps::Corpus)
    ndocs = length(crps.documents)
    #docids = allocate_docids(ndocs)
    # allocate doc ids from one master processor
    docids = remotecall_fetch(1, allocate_docids, ndocs)

    cdocs = documents(crps)

    # assign doc ids
    doc_to_id = Dict{String,Int}()
    for docidx in 1:length(docids)
        doc_to_id[cdocs[docidx].metadata.name] = docids[docidx]
    end
    doc_to_id
end

function as_inverted_index(crps::Corpus, doc_to_id::Dict)
    cdocs = documents(crps)

    update_inverse_index!(crps)
    invidx = inverse_index(crps)

    # update the doc ids in inverted index to global doc ids
    for (n,v) in invidx
        for docidx in 1:length(v)
            docid = v[docidx]
            doc = cdocs[docid]
            path = doc.metadata.name
            v[docidx] = doc_to_id[path]
        end
    end

    invidx
end


function preprocess(entity::Union(StringDocument,Corpus))
    prepare!(entity, strip_corrupt_utf8 | strip_case)
    prepare!(entity, strip_patterns, skip_patterns=Set{String}("<script\\b[^>]*>([\\s\\S]*?)</script>"))
    prepare!(entity, strip_patterns, skip_patterns=Set{String}("<[^>]*>"))
    prepare!(entity, strip_whitespace | strip_non_letters | strip_articles | strip_prepositions | strip_pronouns | strip_stopwords)

    if isa(entity, Corpus)
        standardize!(entity, TokenDocument)
    else
        entity = convert(TokenDocument, entity)
    end
    stem!(entity)
    entity
end

as_serialized(obj, f::File) = as_serialized(obj, f.path)
function as_serialized(obj, path::Union(String,HdfsURL))
    iob = IOBuffer()
    serialize(iob, obj)

    io = open(path, "w")
    write(io, takebuf_array(iob))
    close(io)
    close(iob)
    path
end

index_id = 1
function store_index(invidx::Dict, docids::Dict{String,Int})
    global index_id
    sername = "$(myid())_$(index_id).jser"
    index_id += 1

    path = joinpath(part_idx_location, sername)
    as_serialized(invidx, path)

    path = joinpath(doc_to_id_location, sername)
    as_serialized(docids, path)

    id_to_doc = Dict{Int,String}()
    for (k,v) in docids
        id_to_doc[v] = k
    end
    path = joinpath(id_to_doc_location, sername)
    as_serialized(id_to_doc, path)
end

function create_index(docs::Array)
    crps = Corpus(docs)
    crps = preprocess(crps)
    docids = assign_docids(crps)
    invidx = as_inverted_index(crps, docids)
    store_index(invidx, docids)
    empty!(docs)
end

function read_doc(f::IOStream, docs::Array)
    l = readline(f)
    vs = split(l)

    url = vs[1]
    mime = vs[4]
    len = parseint(vs[5])
    
    if !beginswith(mime, "text/")
        skip(f, len)
        return
    end
    bytes = read(f, Array(Uint8, len))
    ascstr = convert(ASCIIString, bytes, "")
    sd = StringDocument(ascstr)
    sd.metadata = TextAnalysis.DocumentMetadata()
    sd.metadata.name = url
    push!(docs, sd)
end

function create_index(ccpart_filename::String)
    f = GZip.open(joinpath(docs_location, ccpart_filename), "r")
    docs = {} #StringDocument[]
    while !eof(f)
        read_doc(f, docs)
        (length(docs) > ndocs_per_idx_part) && create_index(docs)
    end
    create_index(docs)
    close(f)
end

function create_index(s3Uri::URI)
    fname = basename(s3Uri.path)
    docsfile = joinpath(docs_location, fname)
    if !isfile(docsfile)
        println("downloading $docsfile")
        os = open(docsfile, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get(string(s3Uri), ho)
        close(ho)
    end
    create_index(fname)
    fname
end

function cc_valid_segments(docs_location)
    file = joinpath(docs_location, "valid_segments.txt")
    if !isfile(file)
        os = open(file, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get("http://aws-publicdatasets.s3.amazonaws.com/common-crawl/parse-output/valid_segments.txt", ho)
        close(ho)
    end
    segments = String[]
    open(file) do f
        for str in redlines(f)
            push!(segments, chomp(str))
        end
    end
    segments
end

function cc_archives_in_segment(segment)
    arcnames = URI[]
    env = AWSEnv(timeout=60.0)
    segname = string("common-crawl/parse-output/segment/", segment)
    # TODO: use markers and fetch in chunks
    resp = S3.get_bkt(env, "aws-publicdatasets", options=GetBucketOptions(prefix=segname, maxkeys=100000))
    for elem in resp.obj.contents
        if endswith(elem.key, ".arc.gz")
            push!(arcnames, URI(string("http://aws-publicdatasets.s3.amazonaws.com", elem.key)))
        end
    end
    arcnames
end

function create_index()
    arcnames = URI[]

    # get the valid segments
    segments = cc_valid_segments(docs_location)
    
    segments = segments[1:2]
    for segment in segments
        arcs_in_seg = cc_archives_in_segment(segment)
        append!(arcnames, arcs_in_seq)
    end

    function get_next_arc()
        isempty(arcnames) && return nothing
        pop!(arcnames)
    end

    arcnames = arcnames[1:3]
    arcs_indexed = @parallel append! for arcs in arcnames
        processed = String[]
        for arc in arcnames
            create_index(arc)
            push!(processed, string(arc))
        end
        processed
    end
    println("Archives indexed: $(length(arcs_indexed))")
end

