
if length(ARGS) < 1
    println("Usage: julia shutdown.jl <clustername>")
    exit()
end

include("ccconsts.jl")
include("ccutils.jl")

myinstances=AWS.EC2.ec2_instances_by_owner(get_cluster_name())
AWS.EC2.ec2_terminate(myinstances)

println("DONE!")
