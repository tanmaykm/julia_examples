##
# Configurable constants
######################################################
## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode (not implemented yet)
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc")
const stat_location         = joinpath(fs_pfx, "stats")
#const mime_location         = joinpath(fs_pfx, "mime_counts")
#const domain_location       = joinpath(fs_pfx, "domain_counts")
#const charset_location       = joinpath(fs_pfx, "charset_counts")
const docs_location         = joinpath(fs_pfx, "docs")

