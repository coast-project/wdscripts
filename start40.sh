#!/bin/bash
#
# script to set up variables to start SNiFF+ 4.x
#
# setting up the following variables:
#  DEV_HOME, SNIFF_DIR, SNIFF_BIN_DIR
#-----------------------------------------------------------

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd -P`/$DNAM
else
	mypath=$DNAM
fi

# load common os wrapper funcs
. `dirname $0`/sysfuncs.sh

# see if we have to set sniffdir
if [ -z "${SNIFF_DIR}" ]; then
	SNIFF_DIR=/home/sniff+4.0.1
	SNIFF_BIN_DIR=${SNIFF_DIR}/bin
	SNIFF_ADD_PATH=${SNIFF_DIR}/lib:${SNIFF_DIR}/bin/gnu-win32
	if [ $isWindows -eq 1 ]; then
		# get projectdir in native NT drive:path notation
		getDosDir "$SNIFF_DIR" "SNIFF_DIR"
		export SNIFF_DIR4=${SNIFF_DIR}
	fi
	export SNIFF_DIR
fi
if [ -z "${SNIFF_BIN_DIR}" ]; then
	SNIFF_BIN_DIR=${SNIFF_DIR}/bin
fi
export SNIFF_BIN_DIR

# set config file for windows, sets bash in sh mode
if [ $isWindows -eq 1 ]; then
	export ENV=${SNIFF_DIR}/config/environ.ksh
	export PATH=$PATH:${SNIFF_ADD_PATH}
fi

. ${mypath}/sniffcommon.sh
