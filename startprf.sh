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

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

if [ ! -z "${PERFTESTDIR}" ]; then
	# find all config directories and give a selection
	select cfgdir in `cd ${PROJECTDIR}/${PERFTESTDIR} && find . -name "*config*" -type d`; do
		selectedcfg=$cfgdir
		break;
	done
else
	echo "couldn't locate perftest directory!"
	exit 2
fi
WD_PATH=${selectedcfg}
WD_ROOT=$PROJECTDIR/${PERFTESTDIR}

# set the file handle limit up to 1024
ulimit -n 1024

# start the perftest
$WDA_BIN

# this exit code is needed for scripts starting this one
exit 0
