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

script_name=$(basename "$0")

mypath=$(dirname "$0")
test "/" = "$(echo "${mypath}" | cut -c1)" || mypath="$(cd "${mypath}" 2>/dev/null && pwd)"

# unset all functions to remove potential definitions
# generated using $> sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p' keepwds.sh | grep -v "\$$"
unset -f showhelp
unset -f startIt
unset -f getPid
unset -f killIt
unset -f myExit
unset -f exitproc

showhelp()
{
	# shellcheck source=./config.sh
	. "$mypath"/config.sh >/dev/null 2>&1;
	[ -n "${1}" ] && echo "${1}";
	echo ""
	echo "usage: $script_name [options] [server-params]..."
	echo "where options are:"
	echo " -c <coresize> : maximum size of core file to produce, in 512Byte blocks!"
	echo " -e <level>    : specify level of error-logging to console, default:4, see below for possible values"
	echo " -s <level>    : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5"
	echo "                  possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5"
	echo "                  the logger will log all levels above or equal the specified value"
	echo " -t            : prepend console logs with a timestamp"
	echo " -h <num>      : number of file handles to set for the process, default 1024"
	echo " -C <cfgdir>   : config directory to use within [$PROJECTDIR] directory"
	echo " -D            : print debugging information of scripts, sets PRINT_DBG variable to 1"
	echo " -P            : print full path to wdapp binary (helps with ps -ef command)"
	echo ""
	exit 4;
}

cfg_dbgopt="";
cfg_cfgdir="";
cfg_handles="1024";
PRINT_DBG=0;
cfg_errorlog="";
cfg_syslog="";
cfg_logtimestamp="";
cfg_fullPath="";
cfg_coresize="20000";

# process config switching options first
myPrgOptions=":c:e:s:th:C:PD"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}" opt; do
	case $opt in
		c)
			cfg_coresize="${OPTARG}";
		;;
		:)
			showhelp "ERROR: -$OPTARG parameter missing, exiting!";
		;;
		e)
			if [ "${OPTARG}" -ge 0 ] && [ "${OPTARG}" -le 5 ]; then
				cfg_errorlog="-e ${OPTARG}";
			else
				showhelp "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
			fi
		;;
		s)
			if [ "${OPTARG}" -ge 0 ] && [ "${OPTARG}" -le 5 ]; then
				cfg_syslog="-s ${OPTARG}";
			else
				showhelp "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
			fi
		;;
		t)
			cfg_logtimestamp="-t";
		;;
		h)
			cfg_handles="${OPTARG}";
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			PRINT_DBG=$((PRINT_DBG + 1));
		;;
		P)
			cfg_fullPath="-P";
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $((OPTIND - 1))

cfg_srvopts="$@";

if [ -n "$cfg_cfgdir" ]; then
	COAST_PATH=${cfg_cfgdir};
	export COAST_PATH;
	cfg_cfgdir="-C "${cfg_cfgdir};
fi

[ "${PRINT_DBG:-0}" -ge 1 ] && echo " - sourcing config.sh"
# shellcheck source=./config.sh
. "$mypath"/config.sh

MYNAME=$script_name	# used within trapsignalfuncs/serverfuncs for logging
# install signal handlers
# shellcheck source=./trapsignalfuncs.sh
. "$mypath"/trapsignalfuncs.sh

# source server handling funcs
# shellcheck source=./serverfuncs.sh
. "$mypath"/serverfuncs.sh

_killActive=0;
_stopRetCode=0;

startIt()
{
	# shellcheck disable=SC2086
	${START_SCRIPT} $cfg_dbgopt $cfg_cfgdir $cfg_fullPath \
		-h ${cfg_handles:-1024} -c ${cfg_coresize:-20000} \
		$cfg_errorlog $cfg_syslog $cfg_logtimestamp \
		$cfg_srvopts
	return $?;
}

getPid()
{
	cat "$PID_FILE";
}

killIt()
{
	SignalNumber=${1:-15};
	SignalName="${2:-TERM}";
	_stopRetCode=1;
	if [ $_killActive -eq 0 ]; then
		_killActive=1;
		locPID=$(getServerStatus "${PID_FILE}" "${WDS_BINABS}" "${WDS_BIN}" "${SERVERNAME}" "${RUN_USER}");
		ServerStatus=$?		# 0: server is alive, dead otherwise
		if [ $ServerStatus -eq 0 ]; then
			LogScriptMessage "INFO: stopping server with PID: ${locPID}";
			killedPids="";
			SignalToServer "${SignalNumber}" "${SignalName}" "${locPID}" "killedPids" "${WDS_BIN}" 2>/dev/null
			# give some time ( 600s ) to terminate
			WaitOnTermination 600 ${killedPids} && {
				_stopRetCode=0;
				removeFiles "${PID_FILE}";
			}
		else
			LogScriptMessage "INFO: server has stopped already";
			_stopRetCode=0;
			removeFiles "${PID_FILE}";
		fi
		_killActive=0;
	else
		LogScriptMessage "WARNING: function already active, exiting";
	fi;
	return $_stopRetCode;
}

myExit()
{
	locRetCode=${1:-4};
	LogLeaveScript "${locRetCode}"
	scriptShouldTerminate=1;
	_killActive=0;
	exit "${locRetCode}";
}

# stops possible running processes
exitproc()
{
	locSigName=${1:-4};
	LogScriptMessage "INFO: got SIG${locSigName}";
	scriptShouldTerminate=1;
	_killActive=0;
	killIt;
	myExit $?;
}

scriptShouldTerminate=0;
LogEnterScript

LogScriptMessage "INFO: PID-Filename is [$PID_FILE]";
# start server for the first ( and hopefully last time )
startIt || {
	LogScriptMessage "ERROR: could not start server";
	myExit 1;
}
# keep pid information for later usage
while [ $scriptShouldTerminate -ne 1 ]; do
	test ${PRINT_DBG} -ge 1 && printf "z";
	# don't waste too many cycles
	# -> sleep in an interruptible way by putting it into background and waiting
	sleep 10 &
	wait $!
	test ${PRINT_DBG} -ge 1 && LogScriptMessage "DBG: after sleeping";
	# if we were interrupted by an external signal to kill the server
	#  we need to skip the loop until the signal is handled
	# -> otherwise we potentially start the server more than once!
	test $_killActive -eq 1 && continue;
	# check if pid still exists
	PID=$(getServerStatus "${PID_FILE}" "${WDS_BINABS}" "${WDS_BIN}" "${SERVERNAME}" "${RUN_USER}");
	ServerStatus=$?		# 0: server is alive, dead otherwise
	if [ $ServerStatus -ne 0 ]; then
		# double check, in case someone modified PID_FILE in between
		sleep 1
		PID=$(getServerStatus "${PID_FILE}" "${WDS_BINABS}" "${WDS_BIN}" "${SERVERNAME}" "${RUN_USER}");
		ServerStatus=$?		# 0: server is alive, dead otherwise
		if [ $ServerStatus -ne 0 ]; then
			LogScriptMessage "WARNING: server ${SERVERNAME} [$WDS_BIN] (pid:${PID:-?}) has gone!";
			# make sure server has gone
			killIt;
			test $scriptShouldTerminate -eq 1 && break;
			# restart it if it has gone
			LogScriptMessage "INFO: re-starting server";
			startIt || {
				LogScriptMessage "ERROR: could not re-start server";
				myExit 1;
			}
		fi
	fi
done

# if killing was not successful, try hard again
if [ $_stopRetCode -ne 0 ]; then
	killIt 9 "KILL";
fi;
myExit 0;
