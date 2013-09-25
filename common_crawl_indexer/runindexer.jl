using AWS

include("ccconts.jl")
include("ccutils.jl")

start_ec2_cluster_workers()

require("ccindexer.jl")
@time create_index(2040)
