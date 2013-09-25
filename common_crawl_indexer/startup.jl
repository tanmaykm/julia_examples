using AWS
using HDFS

include("ccconsts.jl")
include("ccutils.jl")

uname = get_cluster_name()
println("Launching $cc_instnum with cluster name $uname")
instances = ec2_launch(cc_ami, cc_sshkey, insttype=cc_insttype, n=cc_instnum, uname=uname, instname="CommonCrawl")

ec2_addprocs(instances, cc_sshkey_file; hostuser="ubuntu")
if (nworkers() != length(instances))
    error("Problem starting required EC2 instances, Exiting...")
    exit()
end

println("Setting up work folders on all instances...")

@everywhere run(`sudo \rm -rf /mnt/cc`)
@everywhere run(`sudo mkdir -p /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)
@everywhere run(`sudo chmod 777 /mnt/cc /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)

println("DONE!")
