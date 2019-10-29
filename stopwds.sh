#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# stops a running wdserver process, specified by its PID which is stored in a file
#

stopwdsScriptName=`basename $0`

mypath=`dirname $0`
test "/" = "`echo ${mypath} | cut -c1`" || mypath=`pwd`/${mypath}

showhelp()
{
	. $mypath/config.sh >/dev/null 2>&1;
	echo ''
	echo 'usage: '$stopwdsScriptName' [options]'
	echo 'where options are:'
	echo ' -C <cfgdir> : config directory to use within ['$PROJECTDIR'] directory'
	echo ' -N <process>: name of process to stop/kill, default is (WDS_BIN)'
	echo ' -U <user>   : name of user the process runs as, default RUN_USER with fallback of USER'
	echo ' -F          : force stopping service even it was disabled by setting RUN_SERVICE=0, deprecated!'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ' -w <count>  : seconds to wait on server termination, default count=60'
	echo ' -K          : force kill server, ignoring server instance token'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_cfgdir="";
cfg_dbg=0;
cfg_hardkill=0;
cfg_waitcount=60;
cfg_procname="";
locRunUser="";
cfg_forceStop=0;

# process config switching options first
myPrgOptions=":C:N:U:w:FDK"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		C)
			cfg_cfgdir=${OPTARG};
		;;
		N)
			cfg_procname="${OPTARG}";
		;;
		U)
			locRunUser="${OPTARG}";
		;;
		F)
			cfg_forceStop=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		K)
			cfg_hardkill=1;
		;;
		w)
			cfg_waitcount=${OPTARG};
		;;
		\?)
			showhelp;
		;;
	esac
done
shift `expr $OPTIND - 1`

if [ -n "$cfg_cfgdir" ]; then
	COAST_PATH=${cfg_cfgdir};
	export COAST_PATH
fi

if [ $cfg_dbg -ge 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

MYNAME=$stopwdsScriptName	# used within trapsignalfuncs/serverfuncs for logging
# install signal handlers
. $mypath/trapsignalfuncs.sh

# source server handling funcs
. $mypath/serverfuncs.sh

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

exitproc()
{
	printf "%s %s: got SIG%s " "`date +%Y%m%d%H%M%S`" "${stopwdsScriptName}" "$1" | tee -a ${ServerMsgLog}
	case $killStep in
		0) printf "when I was initially checking the process!\n" | tee -a ${ServerMsgLog} ;;
		1) printf "when I was trying to send a signal to the process!\n" | tee -a ${ServerMsgLog} ;;
		2) printf "when I was waiting on process termination!\n" | tee -a ${ServerMsgLog} ;;
	esac;
	myExit 0;
}

outmsg="Stopping ${SERVERNAME} server";

LogEnterScript

killStep=0;
sigToSend=15;
sigToSendName="TERM";
if [ ${cfg_hardkill} -eq 1 ]; then
	sigToSend=9;
	sigToSendName="KILL";
fi

sendSignalToServerAndWait ${sigToSend} "${sigToSendName}" "`determineRunUser \"${locRunUser}\"`" ${cfg_waitcount}

myExit $?;
