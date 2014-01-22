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

function store_stats(stats::CorpusStats, sername::String)
    path = joinpath(stat_location, sername)
    as_serialized(stats, path)
end

function stat_archive_file(archive::URI)
    fname = basename(archive.path)
    # since we may end up encountering archive files files from different segments in the crawl corpus with possibly same name,
    # create a unique id as hash of the complete URL. 
    uniqid = bytes2hex(AWS.Crypto.md5(archive.path))
    sername = "$(uniqid).jser"

    # restartability aid: check if archive is processed already and not repeat it
    if isfile(joinpath(stat_location, sername))
        println("skipping $archive already processed as $(sername)")
        return fname
    end

    t1 = time()
    # read all entries from the archive
    f = open(cc, archive)
    entries = read_entries(cc, f, "", 0, true)
    close(f)
    stats = analyze_corpus(entries)
    println("\tprocessing time $(time()-t1)secs")

    t1 = time()
    store_stats(stats, sername)
    println("\tstoring time $(time()-t1)secs")

    # remove the archive file to save space. can be commented if disk space is not an issue
    #clear_cache(cc, archive)
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

function print_gathered_stats()
    stats_list = CorpusStats[]
    for fname in readdir(stat_location)
        path = joinpath(stat_location, fname)
        push!(stats_list, as_deserialized(path))
    end
    stats = merge_corpus_stats(stats_list)
    print_corpus_stats(stats)
end

