#!/bin/bash
if [ `basename $0` == "cleansniff.sh" ]; then
        DNAM=`dirname $0`
        if [ "$DNAM" = "${DNAM#/}" ]; then
                # non absolute path
                mypath=`pwd`/$DNAM
        else
                mypath=$DNAM
        fi
fi
if [ -n "$mypath" ]; then . ${mypath}/config.sh; fi
if [ -z "$FINDEXE" ]; then FINDEXE=find; fi

for dir in `$FINDEXE . "(" -path '*/.sniffdir' -o -path '*/.ProjectCache' -o -path '*/.RetrieverIndex' -o -path '*/.sniffdb' ")" -type d -print`; do
	echo "removing dir  ["$dir"]";
	rm -rf $dir;
done

for name in `$FINDEXE . "(" -name "*%" -o -name ".Sniff*" -o -name ".#*" -o -name "*.rpl[0-9]*" -o -name "*.org[0-9]*" ")" -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
