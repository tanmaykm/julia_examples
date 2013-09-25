using AWS
using HDFS

include("ccconsts.jl")
include("ccutils.jl")

myinstances=AWS.EC2.ec2_instances_by_owner(get_cluster_name())
AWS.EC2.ec2_terminate(myinstances)

println("DONE!")
