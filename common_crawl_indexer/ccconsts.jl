##
# Configurable constants
######################################################
## constants while working in local file system mode
const fs_pfx = ""
## constants while working in HDFS mode
#const fs_pfx = "hdfs://localhost:9000/dinvidx"

const part_idx_location     = joinpath(fs_pfx, "part_idx")
const doc_to_id_location    = joinpath(fs_pfx, "doc_to_id")
const id_to_doc_location    = joinpath(fs_pfx, "id_to_doc")
const docs_location         = joinpath(fs_pfx, "docs")

const ndocs_per_idx_part    = -1

