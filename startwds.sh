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
cfg_handles=1024;
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
# process command line options
while getopts ":a:C:eh:sD" opt; do
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
		e)
			cfg_errorlog=1;
		;;
		h)
			cfg_handles=${OPTARG};
		;;
		s)
			cfg_syslog=1;
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
fi

if [ -n "$cfg_and" ]; then
	echo ' ---- switching configurations to ['$cfg_and'] prior to starting'
	echo ''
	$mypath/setConfig.sh $cfg_and $cfg_opt
fi

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
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

echo '' >> $PROJECTDIR/$LOGDIR/server.msg;
date +'---- [%a %b %e %T %Z %Y] ----' >> $PROJECTDIR/$LOGDIR/server.msg;
printf "starting [%s] on [%s]\n" "${SERVERNAME}" "${HOSTNAME}" >> $PROJECTDIR/$LOGDIR/server.msg;

# set the file handle limit
ulimit -n $cfg_handles

# enable logging if wanted
if [ $cfg_errorlog -eq 1 ]; then
	export WD_LOGONCERR=1;
fi
if [ $cfg_syslog -eq 1 ]; then
	export WD_DOLOG=1;
fi

# start the server process
printf " ---- starting [%s] with options [%s] " "$WDS_BIN" "$cfg_srvopts" | tee -a $PROJECTDIR/$LOGDIR/server.msg
$WDS_BIN $cfg_srvopts 2> $PROJECTDIR/$LOGDIR/server.err >> $PROJECTDIR/$LOGDIR/server.msg &

# this on seems to be simpler to grasp the PID than using ps
WDPID=$!

if [ $? -ne 0 ]; then
	printf "failed !\n"
	exit 3
fi
printf "successful\n" | tee -a $PROJECTDIR/$LOGDIR/server.msg
echo ''
# get the process id from the started process and store it in a file
echo $WDPID > $PID_FILE

# this exit code is needed for scripts starting this one
exit 0
