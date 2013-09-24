- Start a cluster of machines on EC2 (preferably cc2.8xlarge)
- Place the machine hostnames in file instances.txt
- Modify `ccconsts.jl`, `setupfolders.jl` and `runindexer.jl` appropriately
- Execute `julia setupfolders.jl` to create the work folders on all machines
- Execute `julia runindexer.jl` to create the indexes

Note: 
- searcher implementation is not yet complete

