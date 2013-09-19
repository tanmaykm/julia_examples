import nltk, os, pickle, time, sys

from collections import defaultdict
from nltk.stem.snowball import EnglishStemmer

from invidx import Index

def read_as_string(filename):
    with open(filename, 'r') as content_file:
        content = content_file.read()
    return content

print(sys.argv)

if len(sys.argv) > 1:
    if sys.argv[1] == "index":
        time1 = time.time()   
        index = Index(nltk.word_tokenize, read_as_string,
                      EnglishStemmer(), 
                      nltk.corpus.stopwords.words('english'))

        for f in os.listdir("docs"):
            index.add('docs/'+f)

        time2 = time.time()
        with open("pyindex.pickle", 'w') as idx_file:
            pickle.dump(index, idx_file)
        time3 = time.time()

        print("total time: %g secs. index time: %g secs." % ((time3-time1), (time2-time1)))
    elif sys.argv[1] == "search":
        with open("pyindex.pickle", 'r') as idx_file:
            index = pickle.load(idx_file)
        if len(sys.argv) > 2:
            print(index.lookup(sys.argv[2]))
        else:
            test_words = nltk.word_tokenize(read_as_string("docs/w.txt"))
            time4 = time.time()
            for word in test_words:
                index.lookup(word)
            time5 = time.time()

            nwords = len(test_words)
            stime = time5-time4
            print("search time: %g secs for %d words. average: %g secs." % (stime, nwords, stime/nwords))
else:
    print("usage: python invidx.py <index|search>")

