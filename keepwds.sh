#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# starts the server and tries to keep it alive (in case of a crash)
# 
############################################################################

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] [server-params]...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_dbg=0;
# process command line options
while getopts ":a:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}"-a "${OPTARG};
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

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

cfg_srvopts="$*";

# load global config
. $mypath/config.sh $cfg_opt

# stops possible running processes
exitproc()
{
	$SCRIPTDIR/stopwds.sh
	exit 0;
}

trap exitproc INT
trap exitproc HUP
trap exitproc TERM
trap exitproc KILL

# start server for the first ( and hopefully last time )
$SCRIPTDIR/startwds.sh $cfg_opt $cfg_and $cfg_srvopts
if [ $? -eq 0 ]; then
	# keep pid information for later usage
	PID=`cat $PID_FILE`;
	while true; do
		# don't waste too many cycles
		sleep 10;

		# check if pid still exists
		ps -p ${PID} > /dev/null
		if [ $? -ne 0 ]; then
			# for linux we have to kill all threads
			for pid in [`ps -o pid,args | grep $WDS_BIN | grep -v "grep" | awk '{print $1}'`]; do
				echo "killing: $pid"
				kill -9 $pid
			done
			# restart it if it is gone
			$SCRIPTDIR/startwds.sh $cfg_opt $cfg_and $cfg_srvopts
			if [ $? -eq 0 ]; then
				# if it is started again remember the new pid
				PID=`cat $PID_FILE`;
			else
				exit 1;
			fi
		fi
	done
else
	exit 1;
fi

exit 0;
