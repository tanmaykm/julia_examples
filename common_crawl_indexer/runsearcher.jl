using AWS

include("ccconts.jl")
include("ccutils.jl")

if length(ARGS) < 2
    println("Usage: julia runsearcher.jl <clustername> \"search terms as a string\"")
    exit()
end

start_ec2_cluster_workers()

require("ccsearcher.jl")
@time search_index(ARGS[2])
