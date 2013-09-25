- Setup AWS credentials thus:
- export AWS_ID=xxxxxxxx
- export AWS_SECKEY=yyyyyyyyyyyyyyyyyy
- Modify `ccconsts.jl` appropriately. Examine the AWS related constants and make sure they are what you need. 
- The first AMI with a tag key:value of "used_by":"juclass" is selected. If no such AMI is found, cc_default_ami specified in `cconts.jl` is used.  
- Execute `julia startup.jl <clustername>` to start a cluster and setup the nodes for common crawl work
- Execute `julia runindexer.jl <clustername> <num_archives_to_index>` to create the indexes. 
- Execute `julia runsearcher.jl <clustername> "search terms as a string"` to search. 
- Execute `julia shutdown.jl <clustername>` to release all EC2 resources associated with this clustername.

Note: 
- searcher implementation is not yet complete

