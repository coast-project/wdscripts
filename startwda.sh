#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# starts a wdapp
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
	echo 'usage: '$MYNAME' [options] [app-params]...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -e          : enable error-logging to console, default no logging'
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
echo $MYNAME' - script to start application ['${SERVERNAME}'] on ['${HOSTNAME}']'
echo ''

# set the file handle limit
ulimit -n $cfg_handles

# enable logging if wanted
if [ $cfg_errorlog -eq 1 ]; then
	export WD_LOGONCERR=1;
fi
if [ $cfg_syslog -eq 1 ]; then
	export WD_DOLOG=1;
fi

# start the app
echo ' ---- starting ['$WDA_BIN'] with options ['$cfg_srvopts']'
echo ''
$WDA_BIN $cfg_srvopts

# this exit code is needed for scripts starting this one
exit 0
