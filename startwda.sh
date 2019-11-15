#!/bin/sh
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

startwdaScriptName=$(basename $0)

mypath=$(dirname $0)
test "/" = "$(echo ${mypath} | cut -c1)" || mypath="$(cd ${mypath} 2>/dev/null && pwd)"

showhelp()
{
	. $mypath/config.sh >/dev/null 2>&1;
	echo ""
	echo "usage: $startwdaScriptName [options] -- [app-params]..."
	echo "where options are:"
	echo " -c <coresize> : maximum size of core file to produce, in 512Byte blocks!"
	echo " -e <level>    : specify level of error-logging to console, default:4, see below for possible values"
	echo " -s <level>    : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5"
	echo "                  possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5"
	echo "                  the logger will log all levels above or equal the specified value"
	echo " -t            : prepend console logs with a timestamp"
	echo " -h <num>      : number of file handles to set for the process, default 1024"
	echo " -C <cfgdir>   : config directory to use within [$PROJECTDIR] directory"
	echo " -F            : force starting service even it was disabled by setting RUN_SERVICE=0"
	echo " -D            : print debugging information of scripts, sets PRINT_DBG variable to 1"
	echo " -d            : run under debugger control, use a second -d to disable debugging even RUN_ATTACHED_TO_GDB was set to 1"
	echo " -P            : print full path to wdapp binary (helps with ps -ef command)"
	echo ""
	exit 4;
}

locProcPid=0;
cfg_dbgopt="";
cfg_cfgdir="";
cfg_handles="1024";
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
cfg_logtimestamp=0;
swdaGdbBatchfile="";
cfg_dbgctl=0;
cfg_coresize="20000";
cfg_forceStart=0;
cfg_fullPath=0;

# process config switching options first
myPrgOptions=":c:C:de:s:th:FP-D"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}" opt; do
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
		t)
			cfg_logtimestamp=1;
		;;
		c)
			cfg_coresize="${OPTARG}";
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		h)
			cfg_handles="${OPTARG}";
		;;
		F)
			cfg_forceStart=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		d)
			cfg_dbgctl=$((cfg_dbgctl + 1));
		;;
		P)
			cfg_fullPath=1;
		;;
		-)
			break;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $((OPTIND - 1))

cfg_srvopts="$@";
if [ $cfg_dbg -ge 1 ]; then echo " - given Options [$cfg_srvopts]"; fi;

test -n "$cfg_cfgdir" && COAST_PATH=${cfg_cfgdir};
test $cfg_errorlog -gt 0 && COAST_LOGONCERR=$cfg_errorlog;
test $cfg_logtimestamp -gt 0 && COAST_LOGONCERR_WITH_TIMESTAMP=1;
test $cfg_syslog -gt 0 && COAST_DOLOG=$cfg_syslog;

if [ $cfg_dbg -ge 1 ]; then echo " - sourcing config.sh"; fi;
. $mypath/config.sh $cfg_dbgopt

MYNAME=$startwdaScriptName	# used within trapsignalfuncs/serverfuncs for logging
# source server handling funcs
. $mypath/serverfuncs.sh

nologExit()
{
	locRetCode=${1:-4};
	printf "%s\n" "${2}";
	exit ${locRetCode};
}

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

sigToSend=15;
sigToSendName="TERM";

if [ $cfg_fullPath -eq 1 ]; then
	WDA_BIN=$WDA_BINABS;
fi

if [ -z "${WDA_BIN}" ]; then
	LogScriptMessage "ERROR: application binary not defined, cannot start!";
	myExit 1;
fi;

# add SERVERNAME to application options as default
if [ -z "$cfg_srvopts" ]; then
	cfg_srvopts=${SERVERNAME};
fi;

test -w $(dirname ${ServerMsgLog}) || nologExit 1 "Cannot create/write into ${ServerMsgLog}, please ensure correct settings before continuing!";
test -w $(dirname ${ServerErrLog}) || nologExit 1 "Cannot create/write into ${ServerErrLog}, please ensure correct settings before continuing!";

# install signal handlers
. $mypath/trapsignalfuncs.sh

exitproc()
{
	sendSignalToServerAndWait ${sigToSend} "${sigToSendName}" "$(determineRunUser)"
	myExit $?;
}

outmsg="Starting ${SERVERNAME} server";

# check if we have to execute anything depending on RUN_SERVICE setting
# -> this scripts execution will only be disabled when RUN_SERVICE is set to 0
test ${cfg_forceStart} -eq 1 || exitIfDisabledService "${outmsg}"

# check if we want to run under control of gdb
# if you want to use either keepwds.sh or bootScript.sh to start the server, this flag can be set in prjconfig.sh
gdbCommand="";
if [ ${RUN_ATTACHED_TO_GDB:-0} -eq 1 -a $cfg_dbgctl -le 1 -o $cfg_dbgctl -eq 1 ]; then
	gdbCommand="$(findValidGnuToolCommand gdb)";
	if [ $? -eq 0 ]; then
		cfg_dbgctl=1
		swdaGdbBatchfile=$(unset TMPDIR ; mktemp -t);
		generateGdbCommandFile ${swdaGdbBatchfile} "${WDA_BIN}" 0 "${cfg_srvopts}"
	else
		LogScriptMessage "could not find valid gdb executable, starting without gdb!"
		cfg_dbgctl=0;
	fi
fi

echo ""
echo "------------------------------------------------------------------------"
echo "$startwdaScriptName - script to start application [${SERVERNAME}] on [${HOSTNAME}]"
echo ""

LogEnterScript

# set some limits
ulimit -n ${cfg_handles:=1024}
ulimit -c ${cfg_coresize:=20000}

preStartScript=${PROJECTDIRABS}/prjprestart.sh
test -x $preStartScript || preStartScript=${PROJECTDIRABS}/prjprerun.sh # deprecated name
if [ -x "$preStartScript" ]; then
	echo " ---- running (sourcing) local $preStartScript script" | tee -a ${ServerMsgLog};
	. $preStartScript
fi

LogScriptMessage "setting handles to $cfg_handles and coresize to $cfg_coresize blocks"
if [ $cfg_dbgctl -eq 1 ]; then
	if [ $cfg_dbg -ge 1 ]; then
		echo "Generated gdb command file:";
		cat ${swdaGdbBatchfile};
	fi;
	LogScriptMessage "starting ${SERVERNAME} [$WDA_BIN] using GDB with options [$cfg_srvopts] on [${HOSTNAME}]";
	eval ${gdbCommand} --command ${swdaGdbBatchfile}
else
	LogScriptMessage "starting ${SERVERNAME} [$WDA_BIN] with options [$cfg_srvopts] on [${HOSTNAME}]";
	$WDA_BIN $cfg_srvopts &
	locProcPid=$!
	test $locProcPid -ne 0 && test -n "${PID_FILE}" && echo $locProcPid > $PID_FILE;
	if [ $? -ne 0 ]; then
		LogScriptMessage "failed to start process!";
		exit 3
	fi
	LogScriptMessage "started process with pid $locProcPid";
	postStartScript=${PROJECTDIRABS}/prjpoststart.sh
	test -x $postStartScript || postStartScript=${PROJECTDIRABS}/prjpostrun.sh # deprecated name
	if [ -x "$postStartScript" ]
	then
		echo " ---- running (sourcing) local $postStartScript script" | tee -a ${ServerMsgLog};
		. $postStartScript
	fi
	wait
fi
sendSignalToServerAndWait ${sigToSend} "${sigToSendName}" "$(determineRunUser)" 10
myExit $?;
