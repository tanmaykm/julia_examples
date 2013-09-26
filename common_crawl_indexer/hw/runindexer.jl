if length(ARGS) < 2
    println("Usage: julia runindexer.jl <clustername> <num_archives_to_index>")
    exit()
end

# load ccindexer on master node (also required for start_ec2_cluster_workers
require("ccindexer.jl")
start_ec2_cluster_workers()
# load ccindexer on all other nodes
require("ccindexer.jl")

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

@time create_index(int(ARGS[2]))
