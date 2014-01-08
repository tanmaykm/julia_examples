- Setup AWS credentials thus:
- export AWS\_ID=xxxxxxxx
- export AWS\_SECKEY=yyyyyyyyyyyyyyyyyy
- Modify `ccconsts.jl` appropriately. Examine the AWS related constants and make sure they are what you need. 
- In case cc\_ami is not defined, or is an empty string, the first AMI with a tag key:value of "used\_by":"juclass" is used.
- Execute `julia startup.jl <clustername>` to start a cluster and setup the nodes for common crawl work
- Execute `julia runindexer.jl <clustername> <num_archives_to_index>` to create the indexes. 
- Execute `julia runstats.jl <clustername> <num_archives_to_index>` to collect mime type and domain name statistics.
- Execute `julia runsearcher.jl <clustername> "search terms as a string"` to search. Not robust, incomplete currently.
- Execute `julia shutdown.jl <clustername>` to release all EC2 resources associated with this clustername.



Note: 
- searcher implementation is not yet complete

