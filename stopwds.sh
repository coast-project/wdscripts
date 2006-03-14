#!/bin/ksh
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

MYNAME=`basename $0`

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

# source in config switching helper
. $mypath/_cfgSwitch.sh

showhelp()
{
	locPrjDir=` . $mypath/config.sh >/dev/null 2>&1; echo $PROJECTDIR`;
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	PrintSwitchHelp
	echo ' -C <cfgdir> : config directory to use within ['$locPrjDir'] directory'
	echo ' -N <process>: name of process to stop/kill, default is (WDS_BIN)'
	echo ' -U <user>   : name of user the process runs as, default RUN_USER with fallback of USER'
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

# process config switching options first
myPrgOptions=":C:N:U:w:DK"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
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
shift $(($OPTIND - 1))

if [ -n "$cfg_cfgdir" ]; then
	export WD_PATH=${cfg_cfgdir};
fi

# prepare config switching tokens
PrepareTokensForCommandline

# switch configuration now to ensure correct settings
DoSetConfigWithToks

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

# install signal handlers
. $mypath/trapsignalfuncs.sh

# source server handling funcs
. $mypath/serverfuncs.sh

myExit()
{
	locRetCode=${1:-4};
	if [ $locRetCode -eq 0 ]; then
		rm -f $PID_FILE >/dev/null 2>&1;
		rm -f $runUserFile >/dev/null 2>&1;
	fi
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

LogEnterScript

killStep=0;
locWDS_BIN="${WDS_BIN:-${WDA_BIN:-${cfg_procname}}}";
locWDS_BINABS="${WDS_BINABS:-${WDA_BINABS:-${cfg_procname}}}";
runUserFile=${LOGDIR}/.RunUser

if [ -z "${locRunUser}" ]; then
	if [ -f "${runUserFile}" ]; then
		locRunUser=`cat ${runUserFile}`;
	fi;
	locRunUser="${locRunUser:-${USER}}";
fi
if [ -z "${locRunUser}" ]; then
	echo " name of user the process runs as is empty"
	myExit 5;
fi;

if [ -z "${cfg_procname}" -a -n "${locWDS_BIN}" ]; then
	if [ $isWindows -eq 1 ]; then
		# for WIN32 the .exe extension is not shown in the process list, so cut it away
		locWDS_BIN=${locWDS_BIN%${APP_SUFFIX}};
		locWDS_BINABS=${locWDS_BINABS%${APP_SUFFIX}};
	else
		locWDS_BIN=$locWDS_BIN".*"${SERVERNAME};
		locWDS_BINABS=$locWDS_BINABS".*"${SERVERNAME};
	fi;
fi;

# get pid to send signal to
# - normally, there is a PID-File which we use to get the signal-handling PID of the process
#   especially needed on Linux where each thread gets its own process list entry
sigPids="";
if [ -f "$PID_FILE" ]; then
	sigPids="`cat $PID_FILE`";
fi

if [ -z "${locWDS_BIN}" -a -z "${sigPids}" ]; then
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
	echo " name of process to stop empty (WD[AS]_BIN) and no process id from PID-File given, exiting..." | tee -a ${ServerMsgLog}
	myExit 6;
fi;

exitproc()
{
	printf "%s %s: got SIG%s " "`date +%Y%m%d%H%M%S`" "${MYNAME}" "$1" | tee -a ${ServerMsgLog}
	case $killStep in
		0) printf "when I was initially checking the process!\n" | tee -a ${ServerMsgLog} ;;
		1) printf "when I was trying to send a signal to the process!\n" | tee -a ${ServerMsgLog} ;;
		2) printf "when I was waiting on process termination!\n" | tee -a ${ServerMsgLog} ;;
	esac;
	myExit 0;
}

if [ -n "${sigPids}" ]; then
	checkProcessId "${sigPids}"
	if [ $? -eq 0 ]; then
		# server with given pid not alive anymore
		sigPids="";
		rm -f $PID_FILE >/dev/null 2>&1;
	fi
fi

# - fallback is to use the process pids we find in the process list
procPids="";
cpRet=1;
if [ -n "${locWDS_BIN}" ]; then
	checkProcessWithName "${locWDS_BIN}" "${locRunUser}" procPids
	cpRet=$?;
	if [ $cpRet -eq 0 -a "${locWDS_BIN}" != "${locWDS_BINABS}" ]; then
		checkProcessWithName "${locWDS_BINABS}" "${locRunUser}" procPids
		cpRet=$?;
	fi
fi
# if the process with the given PID has gone and the process does not appear in within ps, it seems not to be running anymore
if [ -z "${sigPids}" -a $cpRet -eq 0 ]; then
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
	printf "process (%s) not running, exiting\n" "${locWDS_BIN:-?}" | tee -a ${ServerMsgLog} ${ServerErrLog};
	myExit 7;
fi

sigToSend=15;
sigToSendName="TERM";
if [ ${cfg_hardkill} -eq 1 ]; then
	sigToSend=9;
	sigToSendName="KILL";
fi

sigRet=1;
# send the signal to the pid from the PID-File first
if [ -n "${sigPids}" ]; then
	killStep=1;
	if [ $cfg_dbg -eq 1 ]; then
		echo "sending signal to PID (${sigPids}) from PID-File";
	fi
	SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BIN}"
	if [ $? -eq 1 -a "${locWDS_BIN}" != "${locWDS_BINABS}" ]; then
		# server seems not to be running anymore
		# -> check for dereferenced binary signature in process list too
		SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BINABS}"
	fi;
	sigRet=$?
fi

case $sigRet in
	0)
		# signal successfully sent, need to wait until terminated
		killStep=2;
		WaitOnTermination "${pidKilled}" ${cfg_waitcount}
		myExit $?;
	;;
	1)
		# no pidfile, or server with given pid disappeared
		if [ -n "${procPids}" ]; then
			sigPids="${procPids}";
			killStep=1;
			if [ $cfg_dbg -eq 1 ]; then
				echo "sending signal to PIDs (${sigPids}) of pattern [${locWDS_BIN}]";
			fi
			SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BIN}"
			if [ $? -eq 1 -a "${locWDS_BIN}" != "${locWDS_BINABS}" ]; then
				# server seems not to be running anymore
				# -> check for dereferenced binary signature in process list too
				SignalToServer ${sigToSend} "${sigToSendName}" "${sigPids}" "pidKilled" "${locWDS_BINABS}"
			fi;
			if [ $? -eq 0 ]; then
				# signal successfully sent, need to wait until terminated
				killStep=2;
				WaitOnTermination "${pidKilled}" ${cfg_waitcount}
				myExit $?;
			fi
		fi
		# processes already terminated
		myExit 0;
	;;
	2)
		# processes already terminated
		myExit 0;
	;;
	*)
		# unhandled case
		myExit 3;
	;;
esac
