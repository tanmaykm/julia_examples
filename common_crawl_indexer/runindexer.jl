if length(ARGS) < 2
    println("Usage: julia runindexer.jl <clustername> <num_archives_to_index>")
    exit()
end

require("ccconsts.jl")
start_ec2_cluster_workers()
require("ccindexer.jl")

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

@time create_index(int(ARGS[2]))
