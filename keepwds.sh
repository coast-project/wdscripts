#!/bin/ksh
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

function showhelp
{
	local locPrjDir=` . $mypath/config.sh ; echo $PROJECTDIR`;
	echo ''
	echo 'usage: '$MYNAME' [options] [server-params]...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -e          : enable error-logging to '`( . $mypath/config.sh ; echo ${LOGDIR} )`'/server.err, default no logging'
	echo ' -h <num>    : number of file handles to set for the process, default 1024'
	echo ' -s          : enable error-logging into SysLog, eg. /var/[adm|log]/messages, default no logging into SysLog'
	echo ' -C <cfgdir> : config directory to use within ['$locPrjDir'] directory'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_cfgdir="";
cfg_handles="-h 1024";
cfg_dbg=0;
cfg_errorlog="";
cfg_syslog="";
# process command line options
while getopts ":a:eh:sC:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}"-a "${OPTARG};
		;;
		e)
			cfg_errorlog="-e";
		;;
		h)
			cfg_handles="-h "${OPTARG};
		;;
		s)
			cfg_syslog="-s";
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
			cfg_dbg=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_srvopts="$*";

if [ -n "$cfg_cfgdir" ]; then
	export WD_PATH=${cfg_cfgdir};
	cfg_cfgdir="-c "${cfg_cfgdir};
fi

if [ -n "$cfg_and" ]; then
	echo ' ---- switching configurations to ['$cfg_and'] prior to starting'
	echo ''
	$mypath/setConfig.sh $cfg_and $cfg_opt
fi

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_opt

function startIt
{
	$mypath/startwds.sh $cfg_opt $cfg_and $cfg_cfgdir $cfg_errorlog $cfg_handles $cfg_syslog $cfg_srvopts
	return $?;
}

function killIt
{
	$mypath/stopwds.sh $cfg_opt $cfg_and $cfg_cfgdir
}

doRun=1;

# stops possible running processes
function exitproc
{
	doRun=0;
	killIt;
	exit 0;
}

trap exitproc INT
trap exitproc HUP
trap exitproc TERM
trap exitproc KILL

echo 'PID-File is ['$PID_FILE']';
# start server for the first ( and hopefully last time )
startIt;
if [ $? -eq 0 ]; then
	# keep pid information for later usage
	PID=`cat $PID_FILE`;
	while [ $doRun -eq 1 ]; do
		# don't waste too many cycles
		sleep 10;

		# check if pid still exists
		ps -p ${PID} > /dev/null
		if [ $? -ne 0 ]; then
			echo 'WARNING: process '${SERVERNAME}' (pid:'${PID}') has gone!'
			killIt;
			# restart it if it is gone
			startIt;
			if [ $? -eq 0 ]; then
				# if it is started again remember the new pid
				PID=`cat $PID_FILE`;
				echo 'INFO: getting new pid:'$PID;
			else
				exit 1;
			fi
		fi
	done
else
	exit 1;
fi

killIt;
exit 0;
