#!/bin/bash
#
# script to set up variables to start SNiFF+ 3.2.1
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
	SNIFF_DIR=/home/sniff+
	SNIFF_BIN_DIR=${SNIFF_DIR}/bin
	if [ $isWindows -eq 1 ]; then
		# get projectdir in native NT drive:path notation
		getDosDir "$SNIFF_DIR" "SNIFF_DIR"
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
fi

. ${mypath}/sniffcommon.sh
