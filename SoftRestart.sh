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

. $mypath/config.sh "$@"

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" "$mypath/config.sh";
	exit 4;
fi

# source server handling funcs
. $mypath/serverfuncs.sh

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

LogEnterScript

# get pid to send signal to
# - normally, there is a PID-File which we use to get the signal-handling PID of the process
#   especially needed on Linux where each thread gets its own process list entry
sigPids="";
if [ -f "$PID_FILE" ]; then
	sigPids="`cat $PID_FILE`";
fi

if [ -n "${sigPids}" ]; then
	sigToSend=1;
	sigToSendName="HUP";
	locWDS_BIN="${WDS_BIN:-${WDA_BIN}}";
	locWDS_BINABS="${WDS_BINABS:-${WDA_BINABS}}";
	SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BIN}"
	if [ $? -eq 1 -a "${locWDS_BIN}" != "${locWDS_BINABS}" ]; then
		# server seems not to be running anymore
		# -> check for dereferenced binary signature in process list too
		SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BINABS}"
	fi;
	myExit $?;
else
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
	echo "no process id from PID-File given, exiting..." | tee -a ${ServerMsgLog}
	myExit 4;
fi
