using TextAnalysis
using Blocks
using HDFS
using Base.FS

## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = string(fs_pfx, "part_idx")
const doc_to_id_location    = string(fs_pfx, "doc_to_id.jser")
const id_to_doc_location    = string(fs_pfx, "id_to_doc.jser")
const didx_location         = string(fs_pfx, "didx.jser")
const docs_location         = string(fs_pfx, "docs")

const doc_to_id = Dict{String, Int}()
load_doc_to_id() = merge!(doc_to_id, deserialize(open(doc_to_id_location)))

const id_to_doc = Dict{Int, String}()
load_id_to_doc() = merge!(id_to_doc, deserialize(open(id_to_doc_location)))

next_idx_id = 0

function as_corpus(pathlist::Array)
    sdlist = {}
    for path in pathlist
        io = open(path)
        text = readall(io)
        sd = StringDocument(text)
        sd.metadata = TextAnalysis.DocumentMetadata()
        sd.metadata.name = path
        push!(sdlist, sd)
    end
    Corpus(sdlist)
end

function as_preprocessed(entity)
    remove_case!(entity)
    remove_stop_words!(entity)
    entity
end

function as_inverted_index(crps::Corpus)
    isempty(doc_to_id) && load_doc_to_id()
    cdocs = documents(crps)

    update_inverse_index!(crps)
    invidx = inverse_index(crps)

    # update the doc ids in inverted index to global doc ids
    for (n,v) in invidx
        for docidx in 1:length(v)
            docid = v[docidx]
            doc = cdocs[docid]
            path = doc.metadata.name
            newdocid = doc_to_id[path]
            v[docidx] = newdocid
        end
    end

    invidx
end

as_openable(path) = beginswith(path, "hdfs") ? HdfsURL(path) : File(path)

as_serialized(obj, f::File) = as_serialized(obj, f.path)
function as_serialized(obj, path)
    io = open(path, "w")
    serialize(io, obj)
    close(io)
    path
end

function as_serialized_part_idx(obj::Dict) 
    global next_idx_id
    next_idx_id += 1

    path = joinpath(part_idx_location, string(myid(), '_', next_idx_id, ".jser"))

    as_serialized(obj, path)
end

as_deserialized(a::Array) = map(as_deserialized, a)
as_deserialized(f::File) = as_deserialized(f.path)
function as_deserialized(path)
    io = open(path)
    obj = deserialize(io)
    close(io)
    obj
end

function search_part_idx(a::Array, terms::Array) 
    results = IntSet()
    for part_idx in a
        union!(results, search_part_idx(part_idx, terms))
    end
    results
end
function search_part_idx(part_idx::Dict, terms::Array)
    results = IntSet()
    for term in terms
        union!(results, get(part_idx, term, []))
    end
    results
end

function search_index(terms::String)
    sd = StringDocument(terms)
    as_preprocessed(sd)
    toks = tokens(sd)
    toks = filter(tok->!isempty(tok), toks)
    
    didx = deserialize(open(didx_location))
    didx |> as_deserialized
    result_ids = pmapreduce(part_idx->search_part_idx(part_idx, toks), union!, IntSet(), didx)

    isempty(id_to_doc) && load_id_to_doc()
    result_docs = map(id->get(id_to_doc, id, ""), result_ids)
    filter(x->!isempty(x), result_docs)
end

function create_index()
    docs_loc = as_openable(docs_location)
    part_idx_loc = as_openable(part_idx_location)

    blks = Block(docs_loc, true, 10)
    blks |> as_corpus |> as_preprocessed |> as_inverted_index |> as_serialized_part_idx
    pmap(idx->idx, blks)

    # TODO: squish multiple indices per machine for efficiency
    # Number of indices to squish would depend on the scale at which we are running this

    didx = Block(part_idx_loc, false, 2)
    as_serialized(didx, didx_location)
end


##
# assign ids to each document
# create two indexes to be able to search from either direction
function create_docids()
    d_i = Dict{String, Int}()
    i_d = Dict{Int, String}()
    nextid = 1
    function adddoc(doc_list)
        for doc in doc_list
            d_i[doc] = nextid
            i_d[nextid] = doc
            nextid += 1
        end
    end

    blks = Block(as_openable(docs_location), true, 1000)
    map(adddoc, blks)

    d_i_loc = as_serialized(d_i, as_openable(doc_to_id_location))
    i_d_loc = as_serialized(i_d, as_openable(id_to_doc_location))
    (d_i_loc, i_d_loc)
end

