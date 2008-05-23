#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

if [ "${0%wdenv.sh}" = "${0}" ]; then
	# failed to find scriptname in $0
	# -> use default
	MYNAME=wdenv.sh
	MYNAME=`which wdenv.sh`;
fi;

# check if the caller already used an absolute path to start this script
DNAM=`dirname $MYNAME`
if [ -z "${DNAM}" -o "${DNAM}" = "." ]; then
	DNAM=`which $MYNAME`;
	DNAM=`dirname $DNAM`;
fi
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

showhelp()
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -c                    : clear variables before setting new values'
	echo ' -C <Default Compiler> : set default gcc compiler name to use'
	echo ' -D                    : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ' -E <Dev-Dir-Name>     : set default develop environment name to use, relative name of the directory to be selected, for example DEVELOP'
	echo ''
	exit 4;
}

# load common os wrapper funcs
. ${mypath}/sysfuncs.sh

OPTIND=1
OPTARG=
myDevEnv="";
myDefComp="";
PRINT_DBG=0;
# process command line options
while getopts ":cC:E:D" opt; do
	case $opt in
		c)
			cleanDevelopmentEnv;
		;;
		C)
			myDefComp="${OPTARG}";
		;;
		E)
			myDevEnv="${OPTARG}";
		;;
		D)
			PRINT_DBG=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

setDevelopmentEnv "${myDevEnv}" "${myDefComp}"
if [ $? -eq 0 ]; then
	echo "something went wrong setting Dev-Env, aborting...";
	exit 3;
fi

