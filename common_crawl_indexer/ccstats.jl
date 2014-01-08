using TextAnalysis
using URIParser
#using Stemmers
using Blocks
using HDFS
using Base.FS
using HTTPClient
using CommonCrawl

include("ccconsts.jl")
include("ccutils.jl")

const cc = CrawlCorpus(docs_location, true)

function store_stats(mime_counts::Dict{String,Int}, domain_counts::Dict{String,Int}, sername::String)
    path = joinpath(mime_location, sername)
    as_serialized(mime_counts, path)

    path = joinpath(domain_location, sername)
    as_serialized(domain_counts, path)
end

function stat_archive_file(archive::URI)
    fname = basename(archive.path)
    # since we may end up encountering archive files files from different segments in the crawl corpus with possibly same name,
    # create a unique id as hash of the complete URL. 
    uniqid = bytes2hex(AWS.Crypto.md5(archive.path))
    sername = "$(uniqid).jser"

    # restartability aid: check if archive is processed already and not repeat it
    if isfile(joinpath(domain_location, sername))
        println("skipping $archive already processed as $(sername)")
        return fname
    end

    t1 = time()
    # read all entries from the archive
    f = open(cc, archive)
    entries = read_entries(cc, f, "", 0, true)
    close(f)

    mime_dict = Dict{String, Int}()
    domain_dict = Dict{String, Int}()

    for entry in entries
        mime = entry.mime
        cnt = get(mime_dict, mime, 0) 
        mime_dict[mime] = (cnt + 1)

        try
            u = URI(entry.uri)
            domain_parts = split(u.host, '.')
            domain = (length(domain_parts) == 1) ? domain_parts[1] : join(domain_parts[end-1:], '.')
            cnt = get(domain_dict, domain, 0) 
            domain_dict[domain] = (cnt + 1)
        catch e
            println("error getting domain name from $(entry.uri). $(e)")
        end
    end

    println("\tprocessing time $(time()-t1)secs")

    t1 = time()
    store_stats(mime_dict, domain_dict, sername)
    println("\tstoring time $(time()-t1)secs")

    # remove the archive file to save space. can be commented if disk space is not an issue
    clear_cache(cc, archive)
    fname
end


##
# gather statistics on n_archives
function gather_stats(n_archives::Int)
    arc_file_uris = archives(cc, n_archives)

    println("working with $(length(arc_file_uris)) archive files")
    arcs_indexed = @parallel append! for arc in arc_file_uris
        stat_archive_file(arc)
        [string(arc)]
    end
    println("stats collected for archives: $(length(arcs_indexed))")
end


