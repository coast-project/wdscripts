#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# starts a perftest app, assumes that perftest specific things are stored
#  in a *perftest* directory
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

# source in config switching helper
. $mypath/_cfgSwitch.sh

showhelp()
{
	locPrjDir=` . $mypath/config.sh >/dev/null 2>&1; echo $PROJECTDIR`;
	echo ''
	echo 'usage: '$MYNAME' [options] [perftest-params]...'
	echo 'where options are:'
	PrintSwitchHelp
	echo ' -e <level>  : specify level of error-logging to console, default:4, see below for possible values'
	echo ' -s <level>  : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5'
	echo '                possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5'
	echo '                the logger will log all levels above or equal the specified value'
	echo ' -h <num>    : number of file handles to set for the process, default 1024'
	echo ' -C <cfgdir> : config directory to use within ['$locPrjDir'] directory'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_handles=1024;
cfg_dbg=0;
cfg_errorlog=0;
cfg_syslog=0;
cfg_cfgdir="";

# process config switching options first
myPrgOptions=":C:e:s:h:D"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		:)
			echo "ERROR: -$OPTARG parameter missing, exiting!";
			showhelp;
		;;
		e)
			if [ ${OPTARG} -ge 0 2>/dev/null -a ${OPTARG} -le 5 ]; then
				cfg_errorlog=${OPTARG};
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		s)
			if [ ${OPTARG} -ge 0 -a ${OPTARG} -le 5 ]; then
				cfg_syslog=${OPTARG};
			else
				echo "ERROR: wrong argument [$OPTARG] to option -$opt specified!";
				showhelp;
			fi
		;;
		C)
			cfg_cfgdir=${OPTARG};
		;;
		h)
			cfg_handles=${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_srvopts="$@";

locPERFTESTDIR=`. $mypath/config.sh >/dev/null 2>&1; echo \$PERFTESTDIR`;
locPROJECTDIR=`. $mypath/config.sh >/dev/null 2>&1; echo \$PROJECTDIR`;

if [ -z "${locPERFTESTDIR}" ]; then
	echo ''
	echo 'ERROR: could not locate perftest directory, exiting !'
	showhelp;
fi

# load os-specific settings and functions
. ${mypath}/sysfuncs.sh

if [ -z "$cfg_cfgdir" ]; then
	# find all config directories and give a selection
	SearchJoinedDir "tmpWD_PATH" "${locPROJECTDIR}/${locPERFTESTDIR}" "a" "config" ":";
	oldifs="${IFS}";
	IFS=":";
	select segname in ${tmpWD_PATH}; do
		IFS=$oldifs;
		cfg_cfgdir=$segname
		break;
	done;
fi

export WD_PATH=${locPERFTESTDIR}/${cfg_cfgdir};
SERVERNAME=${locPERFTESTDIR}

# prepare config switching tokens
PrepareTokensForCommandline

# switch configuration now to ensure correct settings
DoSetConfigWithToks

if [ $cfg_dbg -eq 1 ]; then echo ' - sourcing config.sh'; fi;
. $mypath/config.sh $cfg_dbgopt

# add SERVERNAME to application options as default
if [ -n "$cfg_srvopts" ]; then
	cfg_srvopts=$cfg_srvopts" ";
fi
cfg_srvopts=${cfg_srvopts}${SERVERNAME};

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - script to start perftest ['${SERVERNAME}'] with configdir ['${WD_PATH}']'
echo ''

# set the file handle limit
ulimit -n $cfg_handles

# enable logging if wanted
if [ $cfg_errorlog -gt 0 ]; then
	export WD_LOGONCERR=$cfg_errorlog;
fi
if [ $cfg_syslog -gt 0 ]; then
	export WD_DOLOG=$cfg_syslog;
fi

# start the perftest
echo ' ---- starting ['$WDA_BIN'] with options ['$cfg_srvopts']'
echo ''
$WDA_BIN $cfg_srvopts

# this exit code is needed for scripts starting this one
exit 0
