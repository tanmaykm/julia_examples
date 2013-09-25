- Modify `ccconsts.jl` appropriately
- Execute `julia startup.jl <clustername>` to start a cluster and setup the nodes for common crawl work
- Execute `julia runindexer.jl <clustername> <num_archives_to_index>` to create the indexes. 
- Execute `julia runsearcher.jl <clustername> "search terms as a string"` to search. 
- Execute `julia shutdown.jl <clustername>` to release all EC2 resources associated with this clustername.

Note: 
- searcher implementation is not yet complete

