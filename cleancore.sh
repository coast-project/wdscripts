#!/bin/bash
if [ `basename $0` == "cleancore.sh" ]; then
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

for name in `$FINDEXE . -name 'core' -type f -print`; do
	echo "removing file ["$name"]";
	rm -f $name;
done
