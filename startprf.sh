#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# starts a perftest app, assumes that perftest specific things are stored
#  in a *perftest* directory
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
	echo ''
	echo 'usage: '$MYNAME' [options] [perftest-params]...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -c <cfgdir> : config directory to use within ['`( . $mypath/config.sh ; echo ${PERFTESTDIR} )`'] directory'
	echo ' -e          : enable error-logging to console, default no logging'
	echo ' -h <num>    : number of file handles to set for the process, default 1024'
	echo ' -s          : enable error-logging into SysLog, eg. /var/[adm|log]/messages, default no logging into SysLog'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_handles=1024;
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
cfg_cfgdir="";
# process command line options
while getopts ":a:c:eh:sD" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}"-a "${OPTARG};
		;;
		c)
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

# load global config
. $mypath/config.sh $cfg_opt

if [ -z "${PERFTESTDIR}" ]; then
	echo ''
	echo 'ERROR: could not locate perftest directory, exiting !'
	showhelp;
fi

# add SERVERNAME to application options as default
if [ -n "$cfg_srvopts" ]; then
	cfg_srvopts=$cfg_srvopts" ";
fi
cfg_srvopts=${cfg_srvopts}${SERVERNAME};

if [ -z "$cfg_cfgdir" ]; then
	# find all config directories and give a selection
	SearchJoinedDir "tmpWD_PATH" "${PROJECTDIR}/${PERFTESTDIR}" "a" "config" ":";
	oldifs="${IFS}";
	IFS=":";
	select segname in ${tmpWD_PATH}; do
		IFS=$oldifs;
		cfg_cfgdir=$segname
		break;
	done;
fi

export WD_PATH=${cfg_cfgdir};

# change into perftest directory for correct settings of config directory
cd ${PERFTESTDIR}
export WD_ROOT=$PWD;

# need to re-source the config.sh because we changed working directory
echo ' - re-sourcing config.sh'
. $mypath/config.sh $cfg_opt

if [ -n "$cfg_and" ]; then
	echo ' ---- switching configurations to ['$cfg_and'] prior to starting'
	echo ''
	$mypath/setConfig.sh $cfg_and $cfg_opt
	echo ' - re-sourcing config.sh'
	. $mypath/config.sh $cfg_opt
fi

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - script to start perftest ['${SERVERNAME}'] with configdir ['$cfg_cfgdir']'
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

# start the perftest
echo ' ---- starting ['$WDA_BIN'] with options ['$cfg_srvopts']'
echo ''
$WDA_BIN $cfg_srvopts

# this exit code is needed for scripts starting this one
exit 0
