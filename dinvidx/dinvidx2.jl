using TextAnalysis
using Blocks
using HDFS
using Base.FS


##
# Configurable constants
######################################################
## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id.jser")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc.jser")
const docs_location         = joinpath(fs_pfx, "docs")

const ndocs_per_idx_part    = 10


##
# Utility methods
#########################################################
const doc_to_id = Dict{String, Int}()
load_doc_to_id() = merge!(doc_to_id, as_deserialized(openable(doc_to_id_location)))

const id_to_doc = Dict{Int, String}()
load_id_to_doc() = merge!(id_to_doc, as_deserialized(openable(id_to_doc_location)))

next_idx_id = 0

function as_corpus(pathlist::Array)
    sdlist = {}
    for path in pathlist
        io = open(path)
        text = readall(io)
        close(io)
        sd = StringDocument(text)
        sd.metadata = TextAnalysis.DocumentMetadata()
        sd.metadata.name = isa(path, HdfsURL) ? path.url : path
        push!(sdlist, sd)
    end
    Corpus(sdlist)
end

function as_preprocessed(entity)
    remove_corrupt_utf8!(entity)
    remove_punctuation!(entity)
    remove_numbers!(entity)
    remove_case!(entity)
    remove_articles!(entity)
    remove_indefinite_articles!(entity)
    remove_definite_articles!(entity)
    remove_prepositions!(entity)
    remove_pronouns!(entity)
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

openable(path::HdfsURL) = path
openable(path::File) = path
openable(path) = beginswith(path, "hdfs") ? HdfsURL(path) : File(path)

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

    as_serialized(obj, openable(path))
end

# cache deserialized objs to help the simple search implementation speed up by preventing repeated loading of indices
const deser_cache = Dict()
as_deserialized(f::File) = as_deserialized(f.path)
function as_deserialized(path::Union(String,HdfsURL))
    haskey(deser_cache, path) && return deser_cache[path]
    io = as_io(path)
    if isa(path, HdfsURL)
        iob = IOBuffer(read(io, Array(Uint8, nb_available(io)))) # HDFS does not play nicely with byte size reads
        close(io)
        io = iob
    end
    obj = deserialize(io)
    close(io)
    deser_cache[path] = obj
    obj
end

function my_files(blk::Block)
    local_files = {}
    for b in localpart(blk)
        append!(local_files, b)
    end
    local_files
end

##
# Searching
##########################################################

function search_part_idx(part_idx_name, terms::Array)
    part_idx = as_deserialized(part_idx_name)
    results = IntSet()
    for term in terms
        union!(results, get(part_idx, term, []))
    end
    results
end

const dist_idx = Block[]
function master_index() 
    isempty(dist_idx) && push!(dist_idx, Block(openable(part_idx_location), false, 2))
    dist_idx[1]
end

function search_index(terms::String)
    sd = StringDocument(terms)
    as_preprocessed(sd)
    terms = tokens(sd)
    terms = filter(tok->!isempty(tok), terms)
    m = master_index()

    result_doc_ids = @parallel union for i in 1:nworkers()
        files = my_files(m)
        reduce(union, map(file->search_part_idx(file, terms), files))
    end
  
    # map the document ids to file names 
    isempty(id_to_doc) && load_id_to_doc()          # load the id-doc mapping dict only once
    result_docs = map(id->get(id_to_doc, id, ""), result_doc_ids)
    filter(x->!isempty(x), result_docs)
end

##
# Indexing
#####################################################
function create_part_index(files)
    crps = as_corpus(files)
    crps = as_preprocessed(crps)
    inv_idx = as_inverted_index(crps)
    serialized_filename = as_serialized_part_idx(inv_idx)
    serialized_filename
end

function create_index()
    blks = Block(openable(docs_location), true, ndocs_per_idx_part)
    num_parts = @parallel (+) for i in 1:nworkers()
        file_lists = localpart(blks)
        np = 0
        for files in file_lists
            create_part_index(files)
            np += 1
        end
        np
    end
    println("created $num_parts part indices")
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
            docpath = isa(doc, HdfsURL) ? doc.url : doc
            d_i[docpath] = nextid
            i_d[nextid] = docpath
            nextid += 1
        end
    end

    # create blocks (of around 1000 paths each) nested under docs_location
    blks = Block(openable(docs_location), true, 1000)
    for doc_list in blocks(blks)
        adddoc(doc_list)
    end

    d_i_loc = as_serialized(d_i, openable(doc_to_id_location))
    i_d_loc = as_serialized(i_d, openable(id_to_doc_location))
    (d_i_loc, i_d_loc)
end

