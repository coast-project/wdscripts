#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# configuration for scripts, reads also CONFIGDIR/prjconfig.sh for your
#  project specific configuration
#
# YOU SHOULD NOT HAVE TO MODIFY THIS FILE, BECAUSE THIS ONE IS HELD GENERIC
# MODIFY $CONFIGDIR/prjconfig.sh INSTEAD
#
# params:
#   $1 : set to -D for debugging output
#
############################################################################

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" == "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

if [ "$1" == "-D" ]; then
	PRINT_DBG=1
	echo "I am in executing in ["${PWD}"]";
	echo "Scripts dirname is   ["$mypath"]";
	echo
	shift
else
	PRINT_DBG=0
fi

# try to find out on which OS we are currently running, eg. SunOS or Linux
CURSYSTEM=`(uname -s) 2>/dev/null` || CURSYSTEM="unknown"

# points to the directory where the scripts reside
SCRIPTDIR=`cd $mypath 2> /dev/null && pwd`
SCRIPTDIRABS=`cd $mypath 2> /dev/null && pwd -P`

# the directory where all starts
# here we can find project specific directories, eg. config, Docs etc.
PROJECTDIR=`cd $SCRIPTDIR/.. 2> /dev/null && pwd`
PROJECTDIRABS=`cd $SCRIPTDIR/.. 2> /dev/null && pwd -P`

if [ ${CURSYSTEM} == "Windows" ]; then
	# get projectdir in native NT drive:path notation
	PROJECTDIRNT=`cd ${PROJECTDIR} && cmd.exe /c 'cd'`
	# convert path using only forward slashes...
	export PROJECTDIRNT
	PROJECTDIRNT=`awk -v myEnvVar="PROJECTDIRNT" '{}END{ myval=ENVIRON[myEnvVar];gsub("\\\\\\\\", "/", myval); print myval;}' $0`
fi

# check if DEV_HOME contains a trailing slash and append one if not for later comparison
if [ "${DEV_HOME%/}" == "${DEV_HOME}" ]; then
	myDEV_HOME=${DEV_HOME}/
else
	myDEV_HOME=${DEV_HOME}
fi
if [ -z ${DEV_HOME} ]; then
	myDEV_HOME=
fi

if [ "${PROJECTDIR#${myDEV_HOME}}" == "${PROJECTDIR}" -a "${PROJECTDIRABS#${myDEV_HOME}}" == "${PROJECTDIRABS}" ]; then
	echo
	echo "WARNING: DEV_HOME does not point to a parent directory where you currently are!"
	echo
	echo "DEV_HOME is:   [${DEV_HOME}]"
	echo "PROJECTDIR is: [${PROJECTDIR}]"
	echo
fi

# get projectname from projectdirectory, should be the last path segment
PROJECTNAME=${PROJECTDIR##*/}

# needed in deployable version, points to the directory where wd-binaries are in
BINDIR=`cd $PROJECTDIR/bin 2> /dev/null && pwd`

# Test the find version (GNU/std) because of different options
find --version 2> /dev/null
if [ $? == 0 ]; then
	FINDOPT="-maxdepth 1 -printf %f"
	FINDOPT1="-maxdepth 1 -printf %f\n"
else
	echo using std-find;
	FINDOPT="-prune -print"
	FINDOPT1="-prune -print"
fi

# system specific settings
EXEEXT=""
DLLEXT=".so"
if [ ${CURSYSTEM%%-*} == "CYGWIN_NT" ]; then
	CURSYSTEM=Windows
	EXEEXT=".exe"
	DLLEXT=".dll"
fi

# directory name of the log directory, may be overwritten in the project specific config.sh
# for cases where this find does not point to the correct location
LOGDIR=`cd $PROJECTDIR && find . -name "$PROJECTNAME*log*" -follow -type d ${FINDOPT}`

# check if we have a logdir yet
if [ -z $LOGDIR ]; then
	# appropriate log directory not yet found
	for dname in `cd $PROJECTDIR && find . -name "*log*" -follow -type d ${FINDOPT1}`; do
		# take the first we find
		LOGDIR=${dname};
		break;
	done
fi
LOGDIR=${LOGDIR##*/}

# check again if the log directory exists or create one if necessary
if [ -z ${LOGDIR} ]; then
	LOGDIR=logs;
fi

# directory name of the config directory
PERFTESTDIR=`cd $PROJECTDIR && find . -name "$PROJECTNAME*perftest*" -follow -type d ${FINDOPT}`

# check if we have a wd_path yet
if [ -z $PERFTESTDIR ]; then
	# appropriate log directory not yet found
	for dname in `cd $PROJECTDIR && find . -name "*perftest*" -follow -type d ${FINDOPT1}`; do
		# take the first we find
		PERFTESTDIR=${dname};
		break;
	done
fi
PERFTESTDIR=${PERFTESTDIR##*/}

# directory name of the config directory
IntWD_PATH=`cd $PROJECTDIR && find . -name "$PROJECTNAME*config*" -follow -type d ${FINDOPT}`

# check if we have a wd_path yet
if [ -z $IntWD_PATH ]; then
	# appropriate log directory not yet found
	for dname in `cd $PROJECTDIR && find . -name "*config*" -follow -type d ${FINDOPT1} 2>/dev/null`; do
		# take the first we find
		IntWD_PATH=${dname};
		break;
	done
fi
IntWD_PATH=${IntWD_PATH##*/}
if [ "$PRINT_DBG" == 1 ]; then
	echo "IntWD_PATH ["$IntWD_PATH"]"
fi

# check if we have a wd_path yet
if [ -z $WD_PATH ]; then
	# we do not have a wd_path, copy from IntWD_PATH
	WD_PATH=".:"${IntWD_PATH}
	CONFIGDIR=${PROJECTDIR}/${IntWD_PATH}
else
	# we have a wd_path, copy first non-dot segment into IntWD_PATH
	tmpWD_PATH=${WD_PATH};
	tmpSegLast="_dummy_";
	tmpSegment="";
	cfgWD_PATH="";
	while [ ! -z ${tmpWD_PATH} -a "${tmpSegment}" != "${tmpSegLast}" ]; do
		tmpSegLast=${tmpSegment};
		tmpSegment=${tmpWD_PATH%%:*};
		echo "tmpSeg ["${tmpSegment}"]"
		tmpWD_PATH=${tmpWD_PATH#*:};
		echo "tmpWD ["${tmpWD_PATH}"]"
		if [ "${tmpSegment}" != "." -a -d "${PROJECTDIR}/${tmpSegment}" ]; then
			echo "found valid config path ["${tmpSegment}"]";
			cfgWD_PATH=${tmpSegment};
			break;
		fi
	done;
	if [ "$PRINT_DBG" == 1 ]; then
		echo "cfgWD_PATH ["$cfgWD_PATH"]"
	fi
	# check if the path exists, else use the path from above
	if [ ! -z "${cfgWD_PATH}" -a -d "${PROJECTDIR}/${cfgWD_PATH}" ]; then
		CONFIGDIR=${PROJECTDIR}/${cfgWD_PATH}
	else
		CONFIGDIR=${PROJECTDIR}/${IntWD_PATH}
	fi
fi

# try to find out on which machine we are running
HOSTNAME=`(uname -n) 2>/dev/null` || HOSTNAME="unkown"

# check if bindir could be found, when started in development env this is probably not set
# and this is why I use some 'hard' assumptions
if [ -z $BINDIR ]; then
# BINDIR not set, use development defaults
	BINDIR=${DEV_HOME}/WWW/wdapp
	BINDIR=`cd ${BINDIR} && pwd`
	WDS_BIN=${BINDIR}/wdapp${EXEEXT}
	WDA_BIN=${BINDIR}/wdapp${EXEEXT}
else
	BINDIR=`cd ${BINDIR} && pwd`
	WDS_BIN=${BINDIR}/wdapp${EXEEXT}
	WDA_BIN=${BINDIR}/wdapp${EXEEXT}
fi

if [ "$1" == "quantify" ]; then
	export QUANTIFYOPTIONS="-max_threads=500 $QUANTIFYOPTIONS"
	WDS_BIN=${WDS_BIN}.quantify
	WDA_BIN=${WDA_BIN}.quantify
elif [ "$1" == "purify" ]; then
	export PURIFYOPTIONS="-max_threads=500 $PURIFYOPTIONS"
	WDS_BIN=${WDS_BIN}.purify
	WDA_BIN=${WDA_BIN}.purify
fi

# directory where WD-Libs are in
myLIBDIR=`cd $PROJECTDIR/lib 2> /dev/null && pwd`
if [ -z ${myLIBDIR} ]; then
	# now check if WD_LIBDIR is already set
	if [ -z ${WD_LIBDIR} ]; then
		# finally use $DEV_HOME/lib
		myLIBDIR=${DEV_HOME}/lib
	else
		# use WD_LIBDIR
		myLIBDIR=${WD_LIBDIR}
	fi
fi
if [ ! -z ${myLIBDIR} ]; then
	WD_LIBDIR=${myLIBDIR}
else
cat <<EOT

 WARNING: could not find a library directory, looked in:
 PROJECTDIR/lib: [${PROJECTDIR}/lib]
 WD_LIBDIR     : [${WD_LIBDIR}]
 DEV_HOME/lib  : [${DEV_HOME}/lib]

EOT
fi

if [ ${CURSYSTEM} == "Windows" ]; then
	PATH=${WD_LIBDIR}:${PATH}
	export PATH
else
	LD_LIBRARY_PATH=${WD_LIBDIR}:$LD_LIBRARY_PATH
fi

SERVERNAME=$PROJECTNAME
PRJ_DESCRIPTION="itopia $SERVERNAME"
TARGZNAME=$SERVERNAME.tgz
ALL_CONFIGS="itopiaOnly"

# in case where we are installing the prjconfig.sh has to be located in the install directory
if [ ! -f $CONFIGDIR/prjconfig.sh -a ! -f $SCRIPTDIR/prjconfig.sh ]; then
cat << EOT
--------------------------------------------------
ERROR:
project specific config file either in
>> $CONFIGDIR/prjconfig.sh
or
>> $SCRIPTDIR/prjconfig.sh
could not be found, thus bailing out...
--------------------------------------------------
EOT
exit
fi

if [ -f $CONFIGDIR/prjconfig.sh ]; then
	if [ "$PRINT_DBG" == 1 ]; then
		echo "loading $CONFIGDIR/prjconfig.sh"
		echo
	fi
	. $CONFIGDIR/prjconfig.sh
else
	if [ "$PRINT_DBG" == 1 ]; then
		echo "loading $SCRIPTDIR/prjconfig.sh"
		echo
	fi
	. $SCRIPTDIR/prjconfig.sh
fi

# test if the wdapp executable exists, or clear the var if not
if [ ! -x ${WDA_BIN} ]; then
	WDA_BIN=
fi

# test if the server executable exists, or clear the var if not
if [ ! -x ${WDS_BIN} ]; then
	WDS_BIN=
fi

if [ -z ${PID_FILE} ]; then
	PID_FILE=$PROJECTDIR/$LOGDIR/$SERVERNAME.PID
fi

# check if WD_ROOT is already set and if so do not overwrite it but warn about
if [ -z $WD_ROOT  ]; then
	if [ ${CURSYSTEM} == "Windows" ]; then
		WD_ROOT=${PROJECTDIRNT}
	else
		WD_ROOT=${PROJECTDIR}
	fi
else
	echo "WARNING: WD_ROOT already set ["${WD_ROOT}"]"
fi

export ALL_CONFIGS BINDIR CONFIGDIR CURSYSTEM HOSTNAME LD_LIBRARY_PATH WD_LIBDIR LOGDIR PRJ_DESCRIPTION PROJECTDIR PROJECTDIRABS PROJECTNAME SCRIPTDIR SERVERNAME TARGZNAME WD_PATH WD_ROOT

# for debugging only
if [ "$PRINT_DBG" == 1 ]; then
	echo "PID-file:   $PID_FILE"
	echo "allconfigs: $ALL_CONFIGS"
	echo "dfltconfig: $DEF_CONF"
	echo "bindir:     $BINDIR"
	echo "configdir:  $CONFIGDIR"
	echo "cursystem:  $CURSYSTEM"
	echo "hostname:   $HOSTNAME"
	echo "libdir:     $WD_LIBDIR"
	echo "logdir:     $LOGDIR"
if [ ${CURSYSTEM} == "Windows" ]; then
	echo "path:       $PATH"
else
	echo "ld_libpath: $LD_LIBRARY_PATH"
fi
	echo "perftest:   $PERFTESTDIR"
	echo "prjdesc:    $PRJ_DESCRIPTION"
	echo "projectdir: $PROJECTDIR"
	echo "prjdir-abs: $PROJECTDIRABS"
	echo "projectname:$PROJECTNAME"
	echo "scriptdir:  $SCRIPTDIR"
	echo "servername: $SERVERNAME"
	echo "tar-gz-name:$TARGZNAME"
	echo "wd_path:    $WD_PATH"
	echo "wd_root:    $WD_ROOT"
	echo "wdapp:      $WDA_BIN"
	echo "wdserver:   $WDS_BIN"
fi
