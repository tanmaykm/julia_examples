using TextAnalysis
using URIParser
using Stemmers
using Blocks
using HDFS
using Base.FS
using HTTPClient
using AWS
using AWS.S3
using GZip

include("ccconsts.jl")
include("ccutils.jl")

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

function read_doc(f::Union(GZipStream,IOStream), docs::Array)
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
        (ndocs_per_idx_part > 0) && (length(docs) > ndocs_per_idx_part) && create_index(docs)
    end
    create_index(docs)
    close(f)
end

function create_index(s3Uri::URI)
    fname = basename(s3Uri.path)
    docsfile = joinpath(docs_location, fname)
    println("indexing $s3Uri. ($docsfile)")
    if !isfile(docsfile)
        println("\tdownloading $s3Uri to $docsfile")
        t1 = time()
        os = open(docsfile, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get(string(s3Uri), ho)
        close(os)
        println("\tdownloaded in $(time()-t1)secs")
    end
    t1 = time()
    create_index(fname)
    println("\tindexed in $(time()-t1)secs")
    fname
end

function cc_valid_segments(docs_location)
    file = joinpath(docs_location, "valid_segments.txt")
    if !isfile(file)
        println("fetching valid segments...")
        t1 = time()
        os = open(file, "w")
        ho = HTTPClient.HTTPC.RequestOptions(ostream=os)
        get("http://aws-publicdatasets.s3.amazonaws.com/common-crawl/parse-output/valid_segments.txt", ho)
        close(os)
        println("\tfetched in $(time()-t1)secs")
    end
    segments = String[]
    open(file) do f
        for str in readlines(f)
            push!(segments, chomp(str))
        end
    end
    segments
end

function cc_archives_in_segment(segment)
    file = joinpath(docs_location, string("segment_list_",segment,".txt"))
    arcnames = URI[]
    if !isfile(file)
        println("listing segment $segment")
        t1 = time()
        env = AWSEnv(timeout=60.0)
        segname = string("common-crawl/parse-output/segment/", segment)
        os = open(file, "w")
        opts = GetBucketOptions(prefix=segname)
        while true
            # TODO: use markers and fetch in chunks
            resp = S3.get_bkt(env, "aws-publicdatasets", options=opts)
            for elem in resp.obj.contents
                if endswith(elem.key, ".arc.gz")
                    uri_str = string("http://aws-publicdatasets.s3.amazonaws.com/", elem.key)
                    push!(arcnames, URI(uri_str))
                    println(os, uri_str)
                end
                opts.marker = elem.key
            end
            !resp.obj.isTruncated && break
        end
        close(os)
        println("\tfetched in $(time()-t1)secs")
    else
        println("opening cached file [$(file)]")
        open(file) do f
            for str in readlines(f)
                push!(arcnames, URI(chomp(str)))
            end
        end
    end
    arcnames
end

function create_index()
    arcnames = URI[]

    # get the valid segments
    segments = cc_valid_segments(docs_location)
    println("fetched $(length(segments)) segments")
    
    segments = segments[1:2]
    println("working with $(length(segments)) segments")
    for segment in segments
        arcs_in_seg = cc_archives_in_segment(segment)
        append!(arcnames, arcs_in_seg)
        println("fetched $(length(arcs_in_seg)) archive names for segment $(segment)")
    end

    function get_next_arc()
        isempty(arcnames) && return nothing
        pop!(arcnames)
    end

    println("got $(length(arcnames)) archive names")
    arcnames = arcnames[1:3]
    println("working with $(length(arcnames)) archive names")
    arcs_indexed = @parallel append! for arc in arcnames
        create_index(arc)
        [string(arc)]
    end
    println("archives indexed: $(length(arcs_indexed))")
end

