#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# soft-restarts a running wdserver process, specified by its PID which is stored in a file
#
############################################################################

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

if [ -f $PID_FILE ]; then
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
