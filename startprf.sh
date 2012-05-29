#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# starts a perftest app, assumes that perftest specific things are stored
#  in a *perftest* directory
#

startprfScriptName=`basename $0`

mypath=`dirname $0`
test "/" = "`echo ${mypath} | cut -c1`" || mypath=`pwd`/${mypath}

showhelp()
{
	. $mypath/config.sh >/dev/null 2>&1;
	test -n "${1}" && echo "${1}";
	echo ''
	echo 'usage: '$startprfScriptName' [options] -- [perftest-params]...'
	echo 'where options are:'
	echo ' -c <coresize> : maximum size of core file to produce, in 512Byte blocks!'
	echo ' -e <level>    : specify level of error-logging to console, default:4, see below for possible values'
	echo ' -s <level>    : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5'
	echo '                  possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5'
	echo '                  the logger will log all levels above or equal the specified value'
	echo ' -h <num>      : number of file handles to set for the process, default 1024'
	echo ' -C <cfgdir>   : config directory to use within ['$PROJECTDIR'] directory'
	echo ' -F            : force starting service even it was disabled by setting RUN_SERVICE=0'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_cfgdir="";
cfg_handles="-n 1024";
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
cfg_coresize="-c 20000";	# default to 10MB
cfg_forceStart=0;

# process config switching options first
myPrgOptions=":c:C:e:s:h:F-D"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		:)
			showhelp "ERROR: -$OPTARG parameter missing, exiting!";
		;;
		e)
			if [ ${OPTARG} -ge 0 2>/dev/null -a ${OPTARG} -le 5 ]; then
				cfg_errorlog=${OPTARG};
			else
				showhelp "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
			fi
		;;
		s)
			if [ ${OPTARG} -ge 0 -a ${OPTARG} -le 5 ]; then
				cfg_syslog=${OPTARG};
			else
				showhelp "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
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
		F)
			cfg_forceStart=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		-)
			break;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift `expr $OPTIND - 1`

cfg_srvopts="$@";
if [ $cfg_dbg -ge 1 ]; then echo ' - given Options ['$cfg_srvopts']'; fi;

test $cfg_errorlog -gt 0 && COAST_LOGONCERR=$cfg_errorlog;
test $cfg_syslog -gt 0 && COAST_DOLOG=$cfg_syslog;

if [ $cfg_dbg -ge 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

test -n "${PERFTESTDIR}" || showhelp "ERROR: could not locate perftest directory, exiting !";
test -d "${cfg_cfgdir}" || cfg_cfgdir="";
if [ -z "$cfg_cfgdir" ]; then
	# find all config directories and give a selection
	pertfTestConfigdir=`SearchJoinedDir "${PROJECTDIR}/${PERFTESTDIR}" "a" "config" ":"`
	selectInMenu segname ":" "${pertfTestConfigdir}"
	if [ -n "${segname}" ]; then
		cfg_cfgdir=$segname
	fi;
fi

test -n "${cfg_cfgdir}" || showhelp "ERROR: could not locate config directory within perftest directory [${PERFTESTDIR}], exiting !";

COAST_PATH="`prependPathEx \"${COAST_PATH:-${COAST_PATH}}\" \":\" \"${PERFTESTDIR}/${cfg_cfgdir}\"`";
SERVERNAME=${PERFTESTDIR}
SetCOAST_PATH

MYNAME=$startprfScriptName	# used within trapsignalfuncs/serverfuncs for logging
# source server handling funcs
. $mypath/serverfuncs.sh

# add SERVERNAME to application options as default
if [ -z "$cfg_srvopts" ]; then
	cfg_srvopts=${SERVERNAME};
fi;

# install signal handlers
. $mypath/trapsignalfuncs.sh

outmsg="COAST perftest [${SERVERNAME}] with config [${COAST_PATH}]";

# check if we have to execute anything depending on RUN_SERVICE setting
# -> this scripts execution will only be disabled when RUN_SERVICE is set to 0
test ${cfg_forceStart} -eq 1 || exitIfDisabledService "${outmsg}"

echo ''
echo '------------------------------------------------------------------------'
echo $startprfScriptName' - script to start perftest ['${SERVERNAME}'] with configdir ['${COAST_PATH}']'
echo ''

LogEnterScript

myExit()
{
	locRetCode=${1:-4};
	locMessage="${2}";
	test -n "${locMessage}" && LogScriptMessage "${locMessage}";
	LogLeaveScript ${locRetCode}
	exit ${locRetCode};
}

sigToSend=15;
sigToSendName="TERM";

exitproc()
{
	sendSignalToServerAndWait ${sigToSend} "${sigToSendName}" "`determineRunUser`"
	myExit $?;
}

# set some limits
ulimit $cfg_handles
ulimit $cfg_coresize

test -n "${WDA_BIN}" || myExit 1 "application WDA_BIN not defined"
test -x "${WDA_BIN}" || myExit 1 "application [${WDA_BIN}] not executable"

LogScriptMessage "starting ${SERVERNAME} [$WDA_BIN] with options [$cfg_srvopts] on [${HOSTNAME}]";
$WDA_BIN $cfg_srvopts

myExit 0;
