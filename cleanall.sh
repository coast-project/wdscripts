#!/bin/bash

DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

. ${mypath}/cleancore.sh
. ${mypath}/cleanlogs.sh
. ${mypath}/cleansniff.sh
. ${mypath}/cleangenerated.sh
