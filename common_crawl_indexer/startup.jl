if length(ARGS) < 1
    println("Usage: julia runindexer.jl <clustername>")
    exit()
end

include("ccconsts.jl")
include("ccutils.jl")


uname = get_cluster_name()
println("Launching $cc_instnum with cluster name $uname")

if !isdefined(Main, :cc_ami) || (cc_ami == "")

  println("Detecting AMI to use. Looking for AMIs tagged with key:value 'used_by':'juclass' ")
  response = AWS.EC2.DescribeImages(AWS.EC2.AWSEnv(), filterSet=[AWS.EC2.FilterType(name="tag:used_by", valueSet=["juclass"])])

  images = response.obj
  if length(images.imagesSet) > 0
      ami_to_use = images.imagesSet[1].imageId
      println("Found $(length(images.imagesSet)) images. Using $ami_to_use")
  else
      println("AMI not specified. Exiting...")
      exit()
  end
else
  ami_to_use = cc_ami
end

instances = AWS.EC2.ec2_launch(ami_to_use, cc_sshkey, insttype=cc_insttype, n=cc_instnum, uname=uname, instname="CommonCrawl")

# EC2 takes some time to propagate the DNS names and routes after launching the instances, hence the sleep.
#sleep(2.0)

println("Testing TCP connects (on port 22) to all newly started hosts...")
hosts = AWS.EC2.ec2_hostnames(instances)
while true
    try
        for h in hosts
            if cc_driver_on_ec2
                s=connect(h[3], 22)
            else
                s=connect(h[2], 22)
            end
            close(s)
        end
        break;
    catch
        println("Newly started host unreachable. Trying again in 2.0 seconds.")
        sleep(2.0)
    end
end

AWS.EC2.ec2_addprocs(instances, cc_sshkey_file; hostuser="ubuntu", dir=cc_julia_dir, tunnel=!cc_driver_on_ec2, use_public_dnsname=!cc_driver_on_ec2)
if (nworkers() != length(instances))
    error("Problem starting required EC2 instances, Exiting...")
    exit()
end

println("Setting up work folders on all instances...")
@everywhere run(`sudo \rm -rf /mnt/cc`)
@everywhere run(`sudo mkdir -p /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)
@everywhere run(`sudo chmod 777 /mnt/cc /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)

println("DONE!")
