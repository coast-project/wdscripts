#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# starts a wdapp
#
# params
#   $1 : set either to quantify or purify to use specific executables
#
############################################################################

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

# set the file handle limit up to 1024
ulimit -n 1024

# start the app
$WDA_BIN

# this exit code is needed for scripts starting this one
exit 0

