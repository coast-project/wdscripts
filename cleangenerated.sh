#!/bin/bash

if [ `basename $0` == "cleangenerated.sh" ]; then
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

for dir in `$FINDEXE . "(" -path '*/i386_*' -o -path "*/i586*"  -o -path '*/sol_gcc_*' ")" -type d -print`; do
	echo "removing dir  ["$dir"]";
	rm -rf $dir;
done

for name in `$FINDEXE . "(" -name "*.o" -o -name "*.lib" -o -name "*.pdb" -o -name "*.exp" -o -name "*.bak" -o -name "*.plg" -o -name "*.ncb" -o -name "*.aps" ")" -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done

for name in `$FINDEXE . "(" -name "lib*${DLLEXT}" -o -name "wdtest${EXEEXT}" -o -name "${PROJECTNAME}${EXEEXT}" ")" -type f -print`; do
	echo "removing file ["$name"]";
	shortname=${name%.*};
	if [ -f "${shortname}" ]; then
		echo "removing file ["$shortname"]";
		rm -f $shortname;
	fi
	rm -f $name;
done
