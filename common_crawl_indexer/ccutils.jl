using TextAnalysis
using URIParser
using Stemmers
using Blocks
using HDFS
using Base.FS
using HTTPClient
using CommonCrawl

##
# Utility methods
#########################################################
const _cache = Dict()
cache(k, v) = _cache[k] = v
cache_clear(k) = delete!(_cacle, k)
cache_clear() = empty!(_cache)
function cached_get(k, fn)
    v = get(_cache, k, nothing)
    (nothing != v) && return v
    cache(k, fn())
end

openable(path::HdfsURL) = path
openable(path::File) = path
openable(path::String) = beginswith(path, "hdfs") ? HdfsURL(path) : File(path)


# cache deserialized objs to help the simple search implementation speed up by preventing repeated loading of indices
as_deserialized(f::File) = as_deserialized(f.path)
function as_deserialized(path::Union(String,HdfsURL))
    io = as_io(path)
    if isa(path, HdfsURL)
        iob = IOBuffer(read(io, Array(Uint8, nb_available(io)))) # HDFS does not play nicely with byte size reads
        close(io)
        io = iob
    end
    obj = deserialize(io)
    close(io)
    obj
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

function get_cluster_name()
    if length(ARGS) < 1 
        uname=ENV["USER"]
        println("Setting cluster name as $(uname). To specify a different name use:\n\nUsage : julia program_file <cluster_name>")
    else
        uname=ARGS[1]
    end
end


function start_ec2_cluster_workers(uname=get_cluster_name())

    # get instances associated with this owner
    instances=AWS.EC2.ec2_instances_by_owner(uname)

    # start required number of workers on each machine in a loop 
    # since the default limit for an unauthenticated ssh connections is low
    for idx in 1:cc_instnumworkers
        AWS.EC2.ec2_addprocs(instances, cc_sshkey_file; hostuser="ubuntu", use_public_dnsname=cc_driver_on_ec2)
    end

    println("Started $(nworkers())")
end
