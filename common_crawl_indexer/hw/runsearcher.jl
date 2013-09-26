if length(ARGS) < 2
    println("Usage: julia runsearcher.jl <clustername> \"search terms as a string\"")
    exit()
end

# load ccsearcher on master node (also required for start_ec2_cluster_workers
require("ccsearcher.jl")
start_ec2_cluster_workers()
# load ccsearcher on all other nodes
require("ccsearcher.jl")

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

@time search_index(ARGS[2])
