#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# stops a running wdserver process, specified by its PID which is stored in a file
#
############################################################################

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
	echo 'usage: '$MYNAME' [options] [app-params]...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -C <cfgdir> : config directory to use within ['$locPrjDir'] directory'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_cfgdir="";
cfg_dbg=0;
# process command line options
while getopts ":a:C:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}"-a "${OPTARG};
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

if [ -n "$cfg_cfgdir" ]; then
	export WD_PATH=${cfg_cfgdir};
fi

if [ -n "$cfg_and" ]; then
	echo ' ---- switching configurations to ['$cfg_and'] prior to starting'
	echo ''
	$mypath/setConfig.sh $cfg_and $cfg_opt
fi

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_opt

# for WIN32 the .exe extension is not shown in the process list, so cut it away
local locWDS_BIN=${WDS_BIN};
if [ $isWindows -eq 1 ]; then
	locWDS_BIN=${locWDS_BIN%${EXEEXT}};
else
	locWDS_BIN=$locWDS_BIN".*"${SERVERNAME};
fi;

function KillOtherInstances
{
	# process still hanging around so kill it the hard way
	local doFirst=1;
	for pid in `ps -u $LOGNAME -o pid,args | grep "$locWDS_BIN" | grep -v "grep" | awk '{print $1}'`; do
		if [ $doFirst -eq 1 ]; then
			echo 'INFO: killing process ['$locWDS_BIN']'
			doFirst=0;
		fi
		echo 'INFO: killing pid:'$pid
		kill -9 $pid
	done
	if [ $doFirst -eq 1 ]; then
		echo 'INFO: process ['$locWDS_BIN'] did not exist anymore'
	fi;
	rm -f $PID_FILE >/dev/null 2>&1;
}

function WaitOnTermination
{
	if [ $cfg_dbg -eq 1 ]; then echo 'pidfile ['$PID_FILE']'; fi;
	printf "INFO: waiting on its termination "
	loop_counter=1
	max_count=30
	while [ $loop_counter -le $max_count ]; do
		loop_counter=`expr $loop_counter + 1`;
		if [ -f "$PID_FILE" ] ; then
			if [ $isWindows -eq 1 ]; then
				# use -q to suppress output and exit with 0 when matched
				ps -ef | grep -q "${PID}.*${locWDS_BIN}"
			else
				ps -p ${PID} > /dev/null
			fi
			if [ $? -ne 0 ]; then
				rm -f $PID_FILE >/dev/null 2>&1;
				printf "%s\n" "done"
				exit 0
			fi
			printf "."
			sleep 2
		else
			printf "%s\n" "done"
			echo '' >> $PROJECTDIR/$LOGDIR/server.msg;
			date +'---- [%a %b %e %T %Z %Y] ----' >> $PROJECTDIR/$LOGDIR/server.msg;
			printf  "%s on %s with pid %s...stopped\n" ${SERVERNAME} ${HOSTNAME} ${PID} >> $PROJECTDIR/$LOGDIR/server.msg;
			exit 0
		fi
	done
}

if [ -f "$PID_FILE" ]; then
	PID=`cat $PID_FILE`;
	if [ $isWindows -eq 1 ]; then
		# use -q to suppress output and exit with 0 when matched
		ps -ef | grep -q "${PID}.*${locWDS_BIN}"
	else
		ps -p ${PID} > /dev/null
	fi
	if [ $? -ne 0 ]; then
		echo 'WARNING: process with PID:'${PID}' not in processlist!'
		KillOtherInstances
		exit 2
	fi
	printf "INFO: sending TERM signal to %s (pid:%s) on %s " ${SERVERNAME} ${PID} ${HOSTNAME}
	kill -TERM ${PID} 2> /dev/null
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 3
	fi
	printf "was successful\n"
	WaitOnTermination
else
	echo 'WARNING: no PID-file for '${SERVERNAME}
	KillOtherInstances
	exit 2
fi

# we should not end up here, means we couldn't terminate it
KillOtherInstances

exit 0
