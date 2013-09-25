if length(ARGS) < 2
    println("Usage: julia runsearcher.jl <clustername> \"search terms as a string\"")
    exit()
end

require("ccconsts.jl")
start_ec2_cluster_workers()
require("ccsearcher.jl")

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

@time search_index(ARGS[2])
