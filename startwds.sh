#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# starts a wdserver and stores its PID in a file
#
# params
#   $1 : set either to quantify or purify to use specific executables
#
############################################################################

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

printf "starting ${SERVERNAME} on ${HOSTNAME}\n";
date +'---- [%a %b %e %T %Z %Y] ----' >> $PROJECTDIR/$LOGDIR/server.msg;
printf "starting ${SERVERNAME} on ${HOSTNAME}\n" >> $PROJECTDIR/$LOGDIR/server.msg;
			
# set the file handle limit up to 1024
ulimit -n 1024

# start the server process
#$WDS_BIN 2>> $PROJECTDIR/$LOGDIR/server.err >> $PROJECTDIR/$LOGDIR/server.msg &


$WDS_BIN 2> $PROJECTDIR/$LOGDIR/server.err > $PROJECTDIR/$LOGDIR/server.msg &

# this on seems to be simpler to grasp the PID than using ps
WDPID=$!

if [ $? -ne 0 ]; then
	echo "failed to start $WDS_BIN"
	exit 3
fi

# get the process id from the started process and store it in a file
echo $WDPID > $PID_FILE

# this exit code is needed for scripts starting this one
exit 0
