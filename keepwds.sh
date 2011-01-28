#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# starts the server and tries to keep it alive (in case of a crash)
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
if [ -r $mypath/_cfgSwitch.sh ]; then
. $mypath/_cfgSwitch.sh
fi

showhelp()
{
	locPrjDir=` . $mypath/config.sh >/dev/null 2>&1; echo $PROJECTDIR`;
	echo ''
	echo 'usage: '$MYNAME' [options] [server-params]...'
	echo 'where options are:'
	if [ -n "`typeset -f PrintSwitchHelp`" ]; then
		PrintSwitchHelp
	fi
	echo ' -c <coresize> : maximum size of core file to produce, in 512Byte blocks!'
	echo ' -e <level>    : specify level of error-logging to console, default:4, see below for possible values'
	echo ' -s <level>    : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5'
	echo '                  possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5'
	echo '                  the logger will log all levels above or equal the specified value'
	echo ' -h <num>      : number of file handles to set for the process, default 1024'
	echo ' -C <cfgdir>   : config directory to use within ['$locPrjDir'] directory'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ' -P            : print full path to wdapp binary (helps with ps -ef command)'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_cfgdir="";
cfg_handles="-h 1024";
cfg_dbg=0;
cfg_errorlog="";
cfg_syslog="";
cfg_fullPath=0;
cfg_coresize="-c 20000";	# default to 10MB

# process config switching options first
myPrgOptions=":c:e:s:h:C:PD"
if [ -n "`typeset -f ProcessSetConfigOptions`" ]; then
	ProcessSetConfigOptions "${myPrgOptions}" "$@"
fi
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		c)
			cfg_coresize="-c "${OPTARG};
		;;
		:)
			echo "ERROR: -$OPTARG parameter missing, exiting!";
			showhelp;
		;;
		e)
			if [ ${OPTARG} -ge 0 2>/dev/null -a ${OPTARG} -le 5 ]; then
				cfg_errorlog="-e ${OPTARG}";
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		s)
			if [ ${OPTARG} -ge 0 -a ${OPTARG} -le 5 ]; then
				cfg_syslog="-s ${OPTARG}";
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		h)
			cfg_handles="-h "${OPTARG};
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		P)
			cfg_fullPath="-P";
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_srvopts="$@";

if [ -n "$cfg_cfgdir" ]; then
	export COAST_PATH=${cfg_cfgdir};
	cfg_cfgdir="-C "${cfg_cfgdir};
fi

if [ -n "`typeset -f PrepareTokensForCommandline`" ]; then
	# prepare config switching tokens
	PrepareTokensForCommandline
fi
if [ -n "`typeset -f DoSetConfigWithToks`" ]; then
	# switch configuration now to ensure correct settings
	DoSetConfigWithToks
fi

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

# install signal handlers
. $mypath/trapsignalfuncs.sh

# source server handling funcs
. $mypath/serverfuncs.sh

startIt()
{
	$mypath/startwds.sh $cfg_dbgopt $cfg_toks $cfg_cfgdir $cfg_fullPath $cfg_errorlog $cfg_handles $cfg_syslog $cfg_coresize $cfg_srvopts
	return $?;
}

_killActive=0;
_stopRetCode=0;
killIt()
{
	locPIDs="${1}";
	printf "%s %s: killactive: %s PID: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${_killActive}" "${locPIDs}" | tee -a ${ServerMsgLog} >> ${ServerErrLog}
	if [ $_killActive -eq 0 ]; then
		_killActive=1;
		# give some time ( 600s ) to terminate
		printf "%s %s: executing stopwds.sh\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} >> ${ServerErrLog}
		$mypath/stopwds.sh $cfg_dbgopt $cfg_toks $cfg_cfgdir -w 600
		_stopRetCode=$?;
		_killActive=0;
	fi;
	return $_stopRetCode;
}

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

# stops possible running processes
exitproc()
{
	locSigName=${1:-4};
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} >> ${ServerErrLog}
	if [ $cfg_dbg -eq 1 ]; then echo "got SIG${locSigName}"; fi;
	printf "got SIG%s\n" "${locSigName}" | tee -a ${ServerMsgLog} >> ${ServerErrLog}
	doRun=0;
	killIt ${PID};
	myExit $?;
}

doRun=1;
LogEnterScript

printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
printf "PID-Filename is [%s]\n" "$PID_FILE" | tee -a ${ServerMsgLog};
# start server for the first ( and hopefully last time )
startIt;
if [ $? -eq 0 ]; then
	# keep pid information for later usage
	PID=`cat $PID_FILE`;
	while [ $doRun -eq 1 ]; do
		# don't waste too many cycles
		sleep 10;
		# check if pid still exists
		checkProcessId "${PID}"
		if [ $? -eq 0 ]; then
			printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
			printf "WARNING: server %s [%s] (pid:%s) has gone!\n" "${SERVERNAME}" "$WDS_BIN" "${PID}" | tee -a ${ServerMsgLog}
			printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
			printf "stopping potentially running processes\n" | tee -a ${ServerMsgLog}
			killIt "${killPids}";
			# restart it if it has gone
			printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
			printf "re-starting server using startwds.sh\n" | tee -a ${ServerMsgLog}
			startIt;
			if [ $? -eq 0 ]; then
				# if it is started again remember the new pid
				PID=`cat $PID_FILE`;
			else
				printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
				printf "ERROR: could not re-start server, exiting\n" | tee -a ${ServerMsgLog}
				myExit 1;
			fi
		fi
	done
else
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
	printf "ERROR: could not start server, exiting\n" | tee -a ${ServerMsgLog}
	myExit 1;
fi

# wait until kill has finished
while [ $_killActive -eq 1 ]; do
	sleep 1;
done;

# if killing was not successful, try again
if [ $_stopRetCode -ne 0 ]; then
	killIt;
fi;
myExit 0;
