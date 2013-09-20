import nltk, os, pickle, time, sys, glob

from collections import defaultdict
from nltk.stem.snowball import EnglishStemmer

from invidx import Index

def read_as_string(filename):
    with open(filename, 'r') as content_file:
        content = content_file.read()
        content = "".join(i for i in content if ord(i)<128)
    return content

print(sys.argv)

if len(sys.argv) > 1:
    if sys.argv[1] == "index":
        time1 = time.time()   
        begin_doc_id = 0
        index_id = 1

        index = Index(nltk.word_tokenize, read_as_string, EnglishStemmer(), nltk.corpus.stopwords.words('english'))

        for root,subf,files in os.walk("docs"):
            for f in files:
                try:
                    index.add(os.path.join(root,f))
                except:
                    print("error indexing file: " + os.path.join(root,f))

                if index.curr_docid() >= (begin_doc_id+100):
                    with open("pyindex"+str(index_id)+".pickle", 'w') as idx_file:
                        pickle.dump(index, idx_file)
                    index_id += 1
                    begin_doc_id = index.curr_docid()
                    index = Index(nltk.word_tokenize, read_as_string, EnglishStemmer(), nltk.corpus.stopwords.words('english'))
                    index.set_curr_docid(begin_doc_id)

        with open("pyindex"+str(index_id)+".pickle", 'w') as idx_file:
            pickle.dump(index, idx_file)
        time2 = time.time()

        print("index time: %g secs." % ((time2-time1),))

    elif sys.argv[1] == "search":
        idxfiles = glob.glob("pyindex*.pickle")
        time4 = time.time()
        res = []
        for idxfile in idxfiles:
            with open(idxfile, 'r') as idx_file:
                index = pickle.load(idx_file)
                res.extend(index.lookup(sys.argv[2]))
        print(res)
        time5 = time.time()
        stime = time5-time4
        print("search time: %g secs" % (stime,))
else:
    print("usage: python invidx.py <index|search term>")

