using TextAnalysis
using URIParser
using Stemmers
using Blocks
using HDFS
using Base.FS
using HTTPClient
using CommonCrawl

include("ccconsts.jl")
include("ccutils.jl")

const cc = CrawlCorpus(docs_location, true)

_next_doc_id = 1
function allocate_docids(n)
    global _next_doc_id
    docids = _next_doc_id:(_next_doc_id+n-1)
    _next_doc_id += n
    docids
end

function assign_unique_docids(crps::Corpus)
    ndocs = length(crps.documents)

    # allocate doc ids from one master processor
    docids = remotecall_fetch(1, allocate_docids, ndocs)

    cdocs = documents(crps)

    # create a lookup map
    doc_to_id = Dict{String,Int}()
    id_to_doc = Dict{Int,String}()
    for docidx in 1:length(docids)
        d_id = docids[docidx]
        d_name = cdocs[docidx].metadata.name

        doc_to_id[d_name] = d_id
        id_to_doc[d_id] = d_name
    end

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

    # return the id-to-doc map to be used during search
    id_to_doc
end

function store_index(invidx::Dict, id_to_doc::Dict{Int,String}, sername::String)
    path = joinpath(part_idx_location, sername)
    as_serialized(invidx, path)

    path = joinpath(id_to_doc_location, sername)
    as_serialized(id_to_doc, path)
end

function index_archive_file(archive::URI)
    fname = basename(archive.path)
    # since we may end up encountering archive files files from different segments in the crawl corpus with possibly same name,
    # create a unique id as hash of the complete URL. 
    uniqid = bytes2hex(AWS.Crypto.md5(archive.path))
    sername = "$(uniqid).jser"

    # restartability aid: check if archive is indexed already and not repeat it
    if isfile(joinpath(part_idx_location, sername))
        println("skipping $archive already indexed as $(sername)")
        return fname
    end

    t1 = time()
    # read all entries from the archive
    f = open(cc, archive)
    entries = read_entries(cc, f, "text/")
    close(f)

    # create a corpus of StringDocuments
    docs = {}
    for entry in entries
        # ignoring anything otherthan ascii for this example
        ascstr = convert(ASCIIString, entry.data, "")
        sd = StringDocument(ascstr)
        sd.metadata = TextAnalysis.DocumentMetadata()
        sd.metadata.name = entry.uri
        push!(docs, sd)
    end
    crps = Corpus(docs)

    # process the corpus
    crps = preprocess(crps)
    update_inverse_index!(crps)
    invidx = inverse_index(crps)

    # in the corpus, doc ids are allocated starting from 1
    # since we are processing in chunks, we need to make them unique across all runs and all processors
    docids = assign_unique_docids(crps)
    println("\tprocessing time $(time()-t1)secs")

    t1 = time()
    store_index(invidx, docids, sername)
    println("\tstoring time $(time()-t1)secs")

    # remove the archive file to save space. can be commented if disk space is not an issue
    clear_cache(cc, archive)
    fname
end


##
# execute index creation parallely for n_archives archive files
function create_index(n_archives::Int)
    arc_file_uris = archives(cc, n_archives)

    println("working with $(length(arc_file_uris)) archive files")
    arcs_indexed = @parallel append! for arc in arc_file_uris
        index_archive_file(arc)
        [string(arc)]
    end
    println("archives indexed: $(length(arcs_indexed))")
end


