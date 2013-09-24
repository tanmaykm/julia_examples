macs = split(readall("instances.txt"))

for idx in 1:length(macs)
    macs[idx] = string("ubuntu@", macs[idx])
end

println(macs)
addprocs(macs, sshflags=`-i /home/ubuntu/jublr.pem -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no`)

@everywhere run(`sudo \rm -rf /mnt/cc`)
@everywhere run(`sudo mkdir -p /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)
@everywhere run(`sudo chmod 777 /mnt/cc /mnt/cc/part_idx /mnt/cc/id_to_doc /mnt/cc/doc_to_id /mnt/cc/docs`)
