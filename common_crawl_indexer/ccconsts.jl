##
# Configurable constants
######################################################
if !isdefined(Main, :_consts_defined)
const _consts_defined = true

## constants while working in local file system mode
const fs_pfx = "/mnt/cc"
## constants while working in HDFS mode (not implemented yet)
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc")
const docs_location         = joinpath(fs_pfx, "docs")

## AWS constants
const cc_ami = "ami-1b97c272"   # If empty string or is not defined, the first AMI with a tag "used_by":"juclass" will be used
const cc_sshkey = "juclass"
const cc_sshkey_file = "/home/ubuntu/juclass.pem"
const cc_insttype = "m1.large"
const cc_instnum = 2            # Number of EC2 instances        
const cc_instnumworkers = 2     # Number of julia workers per instance
const cc_use_local_node = false # Set this to true, in case you want workers to be started on the local node too
const cc_driver_on_ec2 = true     # Set this to false if you are running your main julia program from outside of EC2
const cc_julia_dir = "/usr/bin"         # Julia installed path on the nightlies installed EC2 AMIs

end
