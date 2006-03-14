#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

MYNAME=`basename $0`

showhelp()
{
	echo ''
	echo 'usage: '$MYNAME' [options] <Dev-Dir-Name>'
	echo 'where options are:'
	echo ' -c : clear variables before setting new values'
	echo 'where Dev-Dir-Name is the relative name of the directory to be selected, for example DEVELOP'
	echo ''
	exit 4;
}

OPTIND=1
OPTARG=

# process command line options
while getopts ":c" opt; do
	case $opt in
		c)
			if [ ${isWindows} -eq 1 ]; then
				deleteFromPath PATH ":" "$WD_LIBDIR";
				unset WD_OUTDIR_NT DEV_HOME_NT;
			else
				deleteFromPath LD_LIBRARY_PATH ":" "$WD_LIBDIR";
			fi
			unset WD_OUTDIR WD_LIBDIR DEV_HOME DEVNAME;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

myparam=$1;

# load common os wrapper funcs
. ${SCRIPTS_DIR:-/home/scripts}/sysfuncs.sh

setDevelopmentEnv "$myparam"
if [ $? -eq 0 ]; then
	echo "something went wrong setting Dev-Env, aborting...";
	exit 3;
fi

