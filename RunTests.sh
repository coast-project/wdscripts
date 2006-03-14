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
	echo ' -e                 : enable error-logging to console, default no logging'
	echo ' -r                 : enable logging of static allocs (object registry), default no logging'
	echo ' -s                 : enable error-logging into SysLog, eg. /var/[adm|log]/messages, default no logging into SysLog'
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
myPrgOptions=":ercm:s-D"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		c)
			cfg_docheckforexe=1;
		;;
		e)
			cfg_errorlog=1;
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
		s)
			cfg_syslog=1;
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
if [ $cfg_errorlog -eq 1 ]; then
	export WD_LOGONCERR=1;
fi
if [ $cfg_syslog -eq 1 ]; then
	export WD_DOLOG=1;
fi
if [ $cfg_staticalloc -eq 1 ]; then
	export TRACE_STATICALLOC=1;
fi

# do the tests now
if [ -f "${cfg_subscript}" ]; then
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
	echo ' ERROR: project specific RunTest script ['${cfg_subscript}'] not found, aborting!';
	ret_code=222;
fi

# this MUST be the last thing we do
exit $ret_code;
