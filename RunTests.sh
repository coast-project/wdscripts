#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

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
	echo ''
	echo 'usage: '$MYNAME' [options] -- TestOptions...'
	echo 'where options are:'
	PrintSwitchHelp
	PrintSubSwitchHelp
	echo ' -c                 : check if test-executable was built, returns 1 on success'
	echo ' -e <level>         : specify level of error-logging to console, default:4, see below for possible values'
	echo ' -s <level>         : specify level of error-logging into SysLog, eg. /var/[adm|log]/messages, default:5'
	echo '                       possible values: Debug:1, Info:2, Warning:3, Error:4, Alert:5'
	echo '                       the logger will log all levels above or equal the specified value'
	echo ' -r                 : enable logging of static allocs (object registry), default no logging'
	echo ' -m <mailaddr>      : mail address of test output receiver, multiple definitions allowed'
	echo ' -D                 : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo 'where TestOptions is:'
	echo ' -all               : do all tests of this suite'
	echo ' -list              : list all existing tests'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_dbg=0;
cfg_mailaddr="";
cfg_errorlog=0;
cfg_syslog=0;
cfg_staticalloc=0;
cfg_docheckforexe=0;

# process config switching options first
myPrgOptions=":e:s:rcm:-D"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		:)
			echo "ERROR: -$OPTARG parameter missing, exiting!";
			showhelp;
		;;
		c)
			cfg_docheckforexe=1;
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
		m)
			if [ -n "$cfg_mailaddr" ]; then
				cfg_mailaddr=${cfg_mailaddr}" ";
			fi
			cfg_mailaddr=${cfg_mailaddr}${OPTARG};
		;;
		r)
			cfg_staticalloc=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
			cfg_dbg=1;
		;;
		-)
			break;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_testparams="$@";

# prepare config switching tokens
PrepareTokensForCommandline

# include global configuration
. ${mypath}/config.sh $cfg_dbgopt

# switch configuration now to ensure correct settings
DoSetConfigWithToks

# allow overriding of cfg_toks variable within common part of prjRunTest.sh
cfg_subscript=`pwd`/prjRunTest.sh;
if [ -f "${cfg_subscript}" ]; then
	# suppress verbosity when only checking for executable
	if [ $cfg_docheckforexe -ne 1 ]; then echo ' ---- using ['${cfg_subscript}'] with param(s) ['$cfg_testparams']'; echo '';fi;
	. ${cfg_subscript}
fi

# test if executable or whatever for tests is there
TestExeOK=0;
if [ -f "${cfg_subscript}" ]; then
	# check if checkTestExe function got defined from prjRunTest.sh sourcing
	# this function can be defined in prjRunTest.sh to support unusual checking of needed files for a test
	if [ -n "`typeset -f checkTestExe`" ]; then
		echo '  --- calling checkTestExe'
		checkTestExe;
		TestExeOK=$?;
		if [ $cfg_dbg -eq 1 ]; then echo 'checkTestExe function returned '$TestExeOK; fi
	else
		if [ -x "${TEST_EXE}" ]; then
			TestExeOK=1;
		fi
		if [ $cfg_dbg -eq 1 ]; then echo 'default ['${TEST_EXE}'] check returned '$TestExeOK; fi
	fi;
fi;
# if -c was selected only check and exit
if [ $cfg_docheckforexe -eq 1 ]; then
	exit $TestExeOK;
fi;

# enable logging if wanted
if [ $cfg_errorlog -gt 0 ]; then
	export WD_LOGONCERR=$cfg_errorlog;
fi
if [ $cfg_syslog -gt 0 ]; then
	export WD_DOLOG=$cfg_syslog;
fi
if [ $cfg_staticalloc -eq 1 ]; then
	export TRACE_STATICALLOC=1;
fi

# do the tests now
if [ -f "${cfg_subscript}" ]; then
	if [ $TestExeOK -eq 1 ]; then
		echo '  --- calling prepareTest'
		# this function MUST be defined in prjRunTest.sh
		prepareTest;

		echo '  --- calling callTest'
		# this function MUST be defined in prjRunTest.sh
		callTest;
		ret_code=$?;

		echo '  --- calling cleanupTest'
		# this function MUST be defined in prjRunTest.sh
		cleanupTest;
	else
		echo '  --- NOT running tests because checkTestExe returned 0!'
		echo ''
		ret_code=33;
	fi
else
	echo ' ERROR: project specific RunTest script ['${cfg_subscript}'] not found, aborting!';
	ret_code=222;
fi

# this MUST be the last thing we do
exit $ret_code;
