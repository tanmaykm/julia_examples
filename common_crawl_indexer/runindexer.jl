using AWS

include("ccconts.jl")
include("ccutils.jl")

if length(ARGS) < 2
    println("Usage: julia runindexer.jl <clustername> <num_archives_to_index>")
    exit()
end

start_ec2_cluster_workers()

require("ccindexer.jl")
@time create_index(int(ARGS[2]))
