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

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

# for WIN32 the .exe extension is not shown in the process list, so cut it away
WDS_BIN=${WDS_BIN%${EXEEXT}}

function KillOtherInstances
{
	# process still hanging around so kill it the hard way
	printf "process did not respond to SIGTERM, killing it now\n"
	for pid in `ps -ef | grep $WDS_BIN | grep -v "grep" | awk '{print $2}'`; do
		echo "killing: $pid"
		kill -9 $pid
	done
	rm $PID_FILE;
}

function WaitOnTermination
{
	loop_counter=1
	max_count=30
	while test $loop_counter -le $max_count; do
		loop_counter=`expr $loop_counter + 1`
		if [ -f "$PID_FILE" ] ; then
			if [ $isWindows -eq 1 ]; then
				# use -q to suppress output and exit with 0 when matched
				ps -ef | grep -q "${PID}.*${WDS_BIN}"
			else
				ps -p ${PID} > /dev/null
			fi
			if [ $? -ne 0 ]; then
				rm $PID_FILE;
				printf "%s\n" "done"
				exit 0
			fi
			printf "."
			sleep 2
		else
			printf "%s\n" "done"
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
		ps -ef | grep -q "${PID}.*${WDS_BIN}"
	else
		ps -p ${PID} > /dev/null
	fi
	if [ $? -ne 0 ]; then
		printf "%s %s\n" ${SERVERNAME} "does not exist anymore"
		KillOtherInstances
		exit 2
	fi
	printf "stopping %s on %s " ${SERVERNAME} ${HOSTNAME}
	printf "with pid %s " ${PID};
	kill -TERM ${PID} 2> /dev/null
	if [ $? -ne 0 ]; then
		printf "%s\n" "failed"
		exit 3
	fi
	printf "%s\n" "was successful"
	WaitOnTermination
else
	printf "%s %s\n" ${SERVERNAME} "not running (no PID-file)"
	KillOtherInstances
	exit 2
fi

# we should not end up here, means we couldn't terminate it
KillOtherInstances

exit 0
