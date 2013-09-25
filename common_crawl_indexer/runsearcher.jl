
if length(ARGS) < 2
    println("Usage: julia runsearcher.jl <clustername> \"search terms as a string\"")
    exit()
end

include("ccconsts.jl")
include("ccutils.jl")


start_ec2_cluster_workers()

cc_use_local_node ? addprocs(cc_instnumworkers) : nothing

require("ccsearcher.jl")
@time search_index(ARGS[2])
