#!/bin/bash
if [ `basename $0` == "cleanlogs.sh" ]; then
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

for name in `$FINDEXE . "(" -name 'Access.log.*' -o -name 'Error.log.*' -o -name 'DBAccess.log.*' -o -name 'DBError.log.*' -o -name 'Import.log.*' -o -name 'MethodTime.log.*' -o -name 'Trace.log.*' ")" -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
