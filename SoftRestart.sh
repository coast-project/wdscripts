#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# soft-restarts a running wdserver process, specified by its PID which is stored in a file
#

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

# load configuration for current project
. $mypath/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" "$mypath/config.sh";
	exit 4;
fi

if [ -f "$PID_FILE" ]; then
	PID=`cat $PID_FILE`;
	ps -p ${PID} > /dev/null
	if [ $? -ne 0 ]; then
		printf "%s with pid %s does not exist anymore\n" ${SERVERNAME} ${PID}
		rm $PID_FILE;
		exit 2
	fi
	printf "soft-restarting %s on %s " ${SERVERNAME} ${HOSTNAME}
	kill -1 ${PID} 2> /dev/null
	if [ $? -ne 0 ]; then
		printf "%s\n" "failed"
		exit 3
	else
		printf "%s\n" "successful"
	fi
else
	printf "%s %s\n" ${SERVERNAME} "not running (no PID-file)"
	exit 2
fi
