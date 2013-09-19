Distributed search index for text files
=======================================

Involves using the following Julia packages:
- HDFS
- Blocks
- TextAnalysis

With the text files in HDFS (or filesystem), the following are roughly the steps:
- List documents and assign numeric IDs to each
- Determine which machines each document is distributed onto and create an equitable distribution of files per machine as Blocks.
- Use map to create multiple inverted indices across all machines. The following is the chain of actions (pseudocode, developed with help of `TextAnalysis` package):
    - `as_corpus |> remove_stop_words |> apply_stemming |> create_inverted_index |> store_index_to_file`
- Reduce the set of inverted indices thus produced into a new `Blocks` instance, which would represent the distributed-index. This can be serialized for later use.
- Use the distributed-index thus created to search. Search would again be a map-reduce using the distributed index.

This gives a very simple distributed index. To improve one can come up with strategies for:
- incremental indexing
- pruning deleted documents
- compacting indices

A python equivalent using NLTK is also present for comparison purposes.

