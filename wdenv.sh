#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
clear

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -c : clear variables before setting new values'
	echo ''
	exit 4;
}

OPTIND=
OPTARG=

# process command line options
while getopts ":fc" opt; do
	case $opt in
		c)
			unset WD_OUTDIR WD_PATH WD_LIBDIR WD_ROOT LD_LIBRARY_PATH;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

# load common os wrapper funcs
. ${SCRIPTS_DIR:-/home/scripts}/sysfuncs.sh

setDevelopmentEnv
if [ $? -eq 0 ]; then
	echo "something went wrong setting Dev-Env, aborting...";
	exit 3;
fi

