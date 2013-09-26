##
# Utility methods
#########################################################

## save an object to a file with the given path
function as_serialized(obj, path::String)
    iob = IOBuffer()
    serialize(iob, obj)
    open(path, "w") do io
        write(io, takebuf_array(iob))
    end
    path
end

## load an object back from a file
function as_deserialized(path::String)
    open(path) do io
        deserialize(io)
    end
end

## clean up text for processing
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
        AWS.EC2.ec2_addprocs(instances, cc_sshkey_file; hostuser="ubuntu", dir=cc_julia_dir, tunnel=!cc_driver_on_ec2, use_public_dnsname=!cc_driver_on_ec2)
    end

    println("Started $(nworkers())")
end
