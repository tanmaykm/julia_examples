if length(ARGS) < 2
    println("Usage: julia runsearcher.jl <clustername> \"search terms as a string\"")
    exit()
end

require("ccsearcher.jl")

start_ec2_cluster_workers()

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

@time search_index(ARGS[2])
