#!/bin/bash
for dir in `find . "(" -path '*/.sniffdir' -o -path '*/.ProjectCache' -o -path '*/.RetrieverIndex' -o -path '*/.sniffdb' ")" -type d -print`; do
	echo "removing dir  ["$dir"]";
	rm -rf $dir;
done

for name in `find . "(" -name "*%" -o -name ".Sniff*" -o -name ".#*" -o -name "*.rpl[0-9]*" -o -name "*.org[0-9]*" ")" -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
