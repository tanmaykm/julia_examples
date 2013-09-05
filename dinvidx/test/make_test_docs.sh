for beg in {a..z}; do echo "${beg}"; grep "^${beg}" /usr/share/dict/words >> ${beg}.txt; done
for beg in {A..Z}; do echo "${beg}"; grep "^${beg}" /usr/share/dict/words >> ${beg}.txt; done

