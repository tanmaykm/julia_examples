using AWS
using HDFS

include("ccconsts.jl")
include("ccutils.jl")

if length(ARGS) < 2
    println("Usage: julia runindexer.jl <clustername> <num_archives_to_index>")
    exit()
end

start_ec2_cluster_workers()

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

require("ccindexer.jl")
@time create_index(int(ARGS[2]))
