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

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

# start server for the first ( and hopefully last time )
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

$SCRIPTDIR/startwds.sh
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
			for pid in [`ps -ef | grep $WDS_BIN | grep -v "grep" | awk '{print $2}'`]; do
				echo "killing: $pid"
				kill -9 $pid
			done
			# restart it if it is gone
			$SCRIPTDIR/startwds.sh
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
