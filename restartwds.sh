#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

DNAM=`dirname $0`
if [ "${DNAM}" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

# load configuration for current project
. ${mypath}/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" ${mypath}/config.sh;
	exit 4;
fi

${mypath}/stopwds.sh
${mypath}/startwds.sh
