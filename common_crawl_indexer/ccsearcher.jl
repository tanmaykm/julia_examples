include("ccconsts.jl")
include("ccutils.jl")


##
# Searching
##########################################################

function search_part_idx(file, terms::Array)
    part_idx = cached_get(file, ()->as_deserialized(file))
    results = IntSet()
    for term in terms
        union!(results, get(part_idx, term, []))
    end
    results
end

function search_index(terms::String)
    sd = StringDocument(terms)
    td = preprocess(sd)
    terms = tokens(td)
    terms = filter(tok->!isempty(tok), terms)

    master_idx = cached_get(part_idx_location, ()->Block(openable(part_idx_location), false, 2))

    result_doc_ids = @parallel union for i in 1:nworkers()
        local_files = {}
        for b in localpart(master_idx)
            append!(local_files, b)
        end
        reduce(union, map(file->search_part_idx(file, terms), local_files))
    end

    println("doc ids: $result_doc_ids")
    # map the document ids to file names 
    #id_to_doc = cached_get(id_to_doc_location, ()->as_deserialized(openable(id_to_doc_location)))
    #result_docs = map(id->get(id_to_doc, id, ""), result_doc_ids)
    #filter(x->!isempty(x), result_docs)
end


