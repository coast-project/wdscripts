#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# starts a wdserver and stores its PID in a file
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

# add SERVERNAME to application options as default
if [ -n "$cfg_srvopts" ]; then
	cfg_srvopts=$cfg_srvopts" ";
fi
cfg_srvopts=${cfg_srvopts}${SERVERNAME};

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - script to start server ['${SERVERNAME}'] on ['${HOSTNAME}']'
echo ''

if [ -n "$cfg_and" ]; then
	echo ' ---- switching configurations to ['$cfg_and'] prior to starting'
	echo ''
	$mypath/setConfig.sh $cfg_and $cfg_opt
	# need to re-source the config.sh - might have switched something needed here like WD_PATH
	. $mypath/config.sh $cfg_opt
fi

date +'---- [%a %b %e %T %Z %Y] ----' >> $PROJECTDIR/$LOGDIR/server.msg;
printf "starting [%s] on [%s]\n" "${SERVERNAME}" "${HOSTNAME}" >> $PROJECTDIR/$LOGDIR/server.msg;

# set the file handle limit up to 1024
ulimit -n 1024

# start the server process
printf " ---- starting [%s] with options [%s] ... " "$WDS_BIN" "$cfg_srvopts"
echo ' ---- starting ['$WDS_BIN'] with options ['$*']' >> $PROJECTDIR/$LOGDIR/server.msg
$WDS_BIN $cfg_srvopts 2> $PROJECTDIR/$LOGDIR/server.err >> $PROJECTDIR/$LOGDIR/server.msg &

# this on seems to be simpler to grasp the PID than using ps
WDPID=$!

if [ $? -ne 0 ]; then
	printf "failed !\n"
	exit 3
fi
printf "successful\n"
echo ''

# get the process id from the started process and store it in a file
echo $WDPID > $PID_FILE

# this exit code is needed for scripts starting this one
exit 0
