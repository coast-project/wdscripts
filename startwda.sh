#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# starts a wdapp
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
	echo 'usage: '$MYNAME' [options] -- [app-params]...'
	echo 'where options are:'
	PrintSwitchHelp
	echo ' -c <coresize> : maximum size of core file to produce, in 512Byte blocks!'
	echo ' -e <level>    : specify level of error-logging to console, default:4, see below for possible values'
	echo ' -s <level>    : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5'
	echo '                  possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5'
	echo '                  the logger will log all levels above or equal the specified value'
	echo ' -h <num>      : number of file handles to set for the process, default 1024'
	echo ' -C <cfgdir>   : config directory to use within ['$locPrjDir'] directory'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

locProcPid=0;
cfg_dbgopt="";
cfg_cfgdir="";
cfg_handles="-n 1024";
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
cfg_hassrvopts=0;
cfg_coresize="-c 20000";	# default to 10MB

# process config switching options first
myPrgOptions=":c:C:e:s:h:-D"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		:)
			echo "ERROR: -$OPTARG parameter missing, exiting!";
			showhelp;
		;;
		e)
			if [ ${OPTARG} -ge 0 2>/dev/null -a ${OPTARG} -le 5 ]; then
				cfg_errorlog=${OPTARG};
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		s)
			if [ ${OPTARG} -ge 0 -a ${OPTARG} -le 5 ]; then
				cfg_syslog=${OPTARG};
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		c)
			cfg_coresize="-c "${OPTARG};
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		h)
			cfg_handles="-n "${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		-)
			cfg_hassrvopts=1;
			break;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_srvopts="$@";
if [ $cfg_dbg -eq 1 ]; then echo ' - given Options ['$cfg_srvopts']'; fi;

if [ -n "$cfg_cfgdir" ]; then
	export WD_PATH=${cfg_cfgdir};
fi

# prepare config switching tokens
PrepareTokensForCommandline

# switch configuration now to ensure correct settings
DoSetConfigWithToks

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

# add SERVERNAME to application options as default
if [ -z "$cfg_srvopts" ]; then
	cfg_srvopts=${SERVERNAME};
fi

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - script to start application ['${SERVERNAME}'] on ['${HOSTNAME}']'
echo ''

# install signal handlers
. $mypath/trapsignalfuncs.sh

# source server handling funcs
. $mypath/serverfuncs.sh

LogEnterScript

exitproc()
{
	if [ $locProcPid -ne 0 ]; then
		sigToSend=15;
		sigToSendName="TERM";
		SignalToServer ${sigToSend} "${sigToSendName}" "${locProcPid}" "pidKilled" "${WDS_BIN}"
		if [ $? -eq 1 -a "${WDS_BIN}" != "${WDS_BINABS}" ]; then
			# server seems not to be running anymore
			# -> check for dereferenced binary signature in process list too
			SignalToServer ${sigToSend} "${sigToSendName}" "${locProcPid}" "pidKilled" "${WDS_BINABS}"
		fi;
		if [ $? -eq 0 ]; then
			WaitOnTermination "${pidKilled}" 60
		fi
	fi
	myExit 0;
}

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
printf "setting handles to %s and coresize to %s blocks\n" "`echo ${cfg_handles}| cut -d ' ' -f 2`" "`echo ${cfg_coresize} | cut -d ' ' -f 2`" | tee -a ${ServerMsgLog}
printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
printf "starting %s [%s] with options [%s] on [%s]\n" "${SERVERNAME}" "$WDS_BIN" "$cfg_srvopts" "${HOSTNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
# set some limits
ulimit $cfg_handles
ulimit $cfg_coresize

# enable logging if wanted
if [ $cfg_errorlog -gt 0 ]; then
	export WD_LOGONCERR=$cfg_errorlog;
fi
if [ $cfg_syslog -gt 0 ]; then
	export WD_DOLOG=$cfg_syslog;
fi

# start the app
prerunscript=./prjprerun.sh
if [ -x "$prerunscript" ]; then
	echo " ---- running (sourcing) local $prerunscript script"
	. $prerunscript
fi
$WDA_BIN $cfg_srvopts &
locProcPid=$!
printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
printf "started process with pid %s\n" "$locProcPid" | tee -a ${ServerMsgLog};
wait
printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
printf "WARNING: server %s [%s] (pid:%s) terminated unexpectedly!\n" "${SERVERNAME}" "$WDS_BIN" "$locProcPid" | tee -a ${ServerMsgLog} ${ServerErrLog};
myExit 1
