import nltk, os, pickle, time, sys

from collections import defaultdict
from nltk.stem.snowball import EnglishStemmer

class Index:
    def __init__(self, tokenizer, docreader, stemmer=None, stopwords=None):
        self.tokenizer = tokenizer
        self.docreader = docreader
        self.stemmer = stemmer
        self.index = defaultdict(list)
        self.documents = {}
        self.__next_docid = 0
        if not stopwords:
            self.stopwords = set()
        else:
            self.stopwords = set(stopwords)
        
    def lookup(self, word):
        word = word.lower()
        if self.stemmer:
            word = self.stemmer.stem(word)

        docids = self.index.get(word)
        if None == docids:
            return []
        return [self.documents.get(docid, None) for docid in docids]

    def next_docid(self, docname):
        self.__next_docid += 1
        docid = self.__next_docid 
        self.documents[docid] = docname
        return docid

    def add(self, docname):
        docid = self.next_docid(docname)
        document = self.docreader(docname)
        document = document.lower()

        for token in nltk.word_tokenize(document):
            if token in self.stopwords:
                continue

            if self.stemmer:
                token = self.stemmer.stem(token)

            if token in self.stopwords:
                continue

            if docid not in self.index[token]:
                self.index[token].append(docid)

