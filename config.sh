#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# configuration for scripts, reads also $CONFIGDIR/prjconfig.sh for your
#  project specific configuration
#
# YOU SHOULD NOT HAVE TO MODIFY THIS FILE, BECAUSE THIS ONE IS HELD GENERIC
# MODIFY $CONFIGDIR/prjconfig.sh INSTEAD
#
# params:
#   $1 : set to -D for debugging output
#

if [ "$1" = "-D" ]; then
	PRINT_DBG=1
	shift
else
	PRINT_DBG=0
fi
export PRINT_DBG

do_quantify=0;
do_purify=0;
if [ "$1" = "quantify" ]; then do_quantify=1; fi
if [ "$1" = "purify" ]; then do_purify=1; fi

if [ $PRINT_DBG -eq 1 ]; then echo 'value of mypath before setting ['$mypath']'; fi
if [ $PRINT_DBG -eq 1 ]; then
	echo 'arg0 is ['$0']'
	echo 'basename of arg0 is ['`basename $0`']'
fi
if [ `basename $0` == "config.sh" ]; then
	# check if the caller already used an absolute path to start this script
	DNAM=`dirname $0`

	if [ "$DNAM" != "${DNAM#*:}" ]; then
		# Windows-style pathname !
		# take care, this one is absolute
		mypath=$DNAM
	elif [ "$DNAM" = "${DNAM#/}" ]; then
		# non absolute path
		mypath=`pwd`/$DNAM
	else
		mypath=$DNAM
	fi
else
	if [ $PRINT_DBG -eq 1 ]; then echo 'I got sourced from within ['$0']'; fi
	# check if the calling script defined mypath variable
	if [ -z "$mypath" ]; then
		echo 'WARNING: calling script or function ['$0'] should define the mypath variable!'
	fi
fi

if [ $PRINT_DBG -eq 1 ]; then
	echo "I am executing in  ["${PWD}"]";
	echo "Scripts dirname is ["$mypath"]";
	echo
fi

# load os-specific settings and functions
. ${mypath}/sysfuncs.sh

# points to the directory where the scripts reside
SCRIPTDIR=`cd $mypath 2> /dev/null && pwd`
SCRIPTDIRABS=`cd $mypath 2> /dev/null && pwd -P`

# the directory where all starts is where we call the script from
# here we can find project specific directories, eg. config, Docs etc.
PROJECTDIR=${PWD}
PROJECTDIRABS=`cd ${PROJECTDIR} 2> /dev/null && pwd -P`

if [ ${isWindows} -eq 1 ]; then
	# get projectdir in native NT drive:path notation
	getDosDir "${PROJECTDIR}" "PROJECTDIRNT"
	getUnixDir "${PROJECTDIR}" "PROJECTDIR"
	getUnixDir "${SCRIPTDIR}" "SCRIPTDIR"
fi

# check if DEV_HOME contains a trailing slash and append one if not for later comparison
if [ "${DEV_HOME%/}" = "${DEV_HOME}" ]; then
	myDEV_HOME=${DEV_HOME}/
else
	myDEV_HOME=${DEV_HOME}
fi
if [ -z "${DEV_HOME}" ]; then
	myDEV_HOME=
fi

if [ -n "$DEV_HOME" -a "$DEV_HOME" != "$PROJECTDIR" -a "${PROJECTDIR#${myDEV_HOME}}" = "${PROJECTDIR}" -a "${PROJECTDIRABS#${myDEV_HOME}}" = "${PROJECTDIRABS}" ]; then
	echo ''
	echo 'WARNING: DEV_HOME already set to ['$DEV_HOME'] but projectdir is ['$PROJECTDIR']'
	echo ''
fi

# get projectname from projectdirectory, should be the last path segment
PROJECTNAME=${PROJECTDIR##*/}

# needed in deployable version, points to the directory where wd-binaries are in
BINDIR=`cd $PROJECTDIR/bin 2>/dev/null && pwd`

# set default binary name to execute either in foreground or background
# in case of Coast this is almost always wdapp
APP_NAME=wdapp
TEST_NAME=wdtest

# directory name of the log directory, may be overwritten in the project specific prjconfig.sh
SearchJoinedDir "LOGDIR" "$PROJECTDIR" "$PROJECTNAME" "log"
if [ $? -eq 0 ]; then
	# failed to get dir, use current dir as log-directory
	LOGDIR=.;
fi

# directory name of the perftest directory, if any
SearchJoinedDir "PERFTESTDIR" "$PROJECTDIR" "$PROJECTNAME" "perftest"

# directory name of the source directory
SearchJoinedDir "PROJECTSRCDIR" "$PROJECTDIR" "$PROJECTNAME" "src"

# directory name of the config directory
SearchJoinedDir "IntWD_PATH" "$PROJECTDIR" "$PROJECTNAME" "config"
if [ $PRINT_DBG -eq 1 ]; then
	echo "IntWD_PATH ["$IntWD_PATH"]"
fi

SetWD_PATH()
{
	# check if we have a wd_path yet
	if [ -z "$WD_PATH" ]; then
		# we do not have a wd_path, copy from IntWD_PATH or use . if empty
		appendPath "WD_PATH" ":" "${IntWD_PATH:-.}"
		CONFIGDIR=${IntWD_PATH:-.};
	else
		# we have a wd_path, copy first existing segment into CONFIGDIR
		tmpWD_PATH=${WD_PATH};
		CONFIGDIR="";
		WD_PATH="";
		oldifs="${IFS}";
		IFS=":";
		for segname in ${tmpWD_PATH}; do
			IFS=$oldifs;
			if [ $PRINT_DBG -eq 1 ]; then echo "segment is ["$segname"]"; fi
			if [ -d "${segname}" ]; then
				if [ $PRINT_DBG -eq 1 ]; then echo "found valid config path ["${segname}"]"; fi
				if [ $PRINT_DBG -eq 1 ]; then echo "wd-path before ["$WD_PATH"]"; fi
				appendPath "WD_PATH" ":" "${segname}";
				if [ -z "$CONFIGDIR" ]; then
					CONFIGDIR=${segname};
				fi
			fi
		done;
		if [ -z "$CONFIGDIR" ]; then
			CONFIGDIR=".";
		fi

		# if someone would better like to use the path found in IntWD_PATH instead of the existing
		#  path in WD_PATH he could add a switch to enable the following code
		if [ 1 -eq 0 ]; then
			prependPath "WD_PATH" ":" "${IntWD_PATH}"
			CONFIGDIR=${IntWD_PATH};
		fi
	fi
	CONFIGDIRABS=`cd ${PROJECTDIR}/${CONFIGDIR} 2>/dev/null && pwd -P`;
}

# set the WD_PATH
SetWD_PATH

# try to find out on which machine we are running
HOSTNAME=`(uname -n) 2>/dev/null` || HOSTNAME="unkown"
DOMAIN=$(getdomain "${HOSTNAME}")

SetBindir()
{
	# check if bindir could be found, when started in development env this is probably not set
	if [ -z "$BINDIR" ]; then
		if [ -n "$DEV_HOME" ]; then
			# we are in development environment
			if [ "${APP_NAME}" == "wdapp" ]; then
				# BINDIR not set, use development defaults
				BINDIR=${DEV_HOME}/wdapp/${OSREL}
			else
				BINDIR=${PROJECTDIR}/${OSREL}
			fi
		else
			# we are in deployed env but nothing could be found...
			echo "failed when looking for a valid BINDIR..."
		fi
	fi
	BINDIRABS=`cd ${BINDIR} 2>/dev/null && pwd -P`;
}

SetBinary()
{
	if [ -n "$BINDIR" ]; then
		WDS_BIN=${BINDIR}/${APP_NAME}${APP_SUFFIX}
		WDA_BIN=${BINDIR}/${APP_NAME}${APP_SUFFIX}
		WDS_BINABS=${BINDIRABS}/${APP_NAME}${APP_SUFFIX}
		WDA_BINABS=${BINDIRABS}/${APP_NAME}${APP_SUFFIX}
	fi

	if [ $do_quantify -eq 1 ]; then
		export QUANTIFYOPTIONS="-max_threads=500 $QUANTIFYOPTIONS"
		WDS_BIN=${WDS_BIN}.quantify
		WDA_BIN=${WDA_BIN}.quantify
	elif [ $do_purify -eq 1 ]; then
		export PURIFYOPTIONS="-max_threads=500 $PURIFYOPTIONS"
		WDS_BIN=${WDS_BIN}.purify
		WDA_BIN=${WDA_BIN}.purify
	fi
}

TestExecWdBinaries()
{
	# test if the wdapp executable exists, or clear the var if not
	if [ ! -x ${WDA_BIN} ]; then
		WDA_BIN=
	fi

	# test if the server executable exists, or clear the var if not
	if [ ! -x ${WDS_BIN} ]; then
		WDS_BIN=
	fi
}

SetupTestExe()
{
	##foo maybe move this out into RunTests.sh
	# check for wdtest executable
	if [ -d "${OSREL}" ]; then
		for exename in ${OSREL}/${TEST_NAME}${APP_SUFFIX} `ls ${OSREL}/${TEST_NAME}* 2>/dev/null`; do
			if [ $PRINT_DBG -eq 1 ]; then echo 'testing excutable ['${exename}']'; fi;
			if [ -f "$exename" -a -x "$exename" ]; then
				if [ $PRINT_DBG -eq 1 ]; then echo 'using excutable ['${exename}']'; fi;
				TEST_EXE=$exename;
				break;
			fi
		done
	else
		for exename in ${BINDIR}/${TEST_NAME}* ${PROJECTDIR}/${TEST_NAME}*; do
			if [ $PRINT_DBG -eq 1 ]; then echo 'trying executable ['$exename']'; fi
			if [ -n "$exename" -a -f "$exename" -a -x "$exename" ]; then
				export TEST_EXE=$exename;
				if [ $PRINT_DBG -eq 1 ]; then echo 'exporting TEST_EXE=['$exename']'; fi
				break;
			fi
		done
	fi
}

# directory where WD-Libs are in
if [ -d "$PROJECTDIR/lib" ]; then
	myLIBDIR=`cd $PROJECTDIR/lib && pwd`
fi
if [ -z "${myLIBDIR}" ]; then
	# now check if WD_LIBDIR is already set
	if [ -z "${WD_LIBDIR}" ]; then
		if [ -n "$DEV_HOME" ]; then
			# finally use $DEV_HOME/lib
			myLIBDIR=${DEV_HOME}/lib
		fi
	else
		# use WD_LIBDIR
		myLIBDIR=${WD_LIBDIR}
	fi
fi
if [ -n "${myLIBDIR}" ]; then
	WD_LIBDIR=${myLIBDIR}
else
	echo 'WARNING: could not find a library directory, looked in:'
	echo 'PROJECTDIR/lib: ['${PROJECTDIR}/lib']'
	echo 'WD_LIBDIR     : ['${WD_LIBDIR}']'
	echo 'DEV_HOME/lib  : ['${DEV_HOME}/lib']'
fi

if [ $isWindows -eq 1 ]; then
	cleanPath "PATH" ":"
	prependPath "PATH" ":" "${WD_LIBDIR}"
else
	cleanPath "LD_LIBRARY_PATH" ":"
	prependPath "LD_LIBRARY_PATH" ":" "${WD_LIBDIR}"
fi

if [ -z "${SERVERNAME}" ]; then
	SERVERNAME=$PROJECTNAME
fi;
PRJ_DESCRIPTION="$SERVERNAME"
TARGZNAME=$SERVERNAME.tgz

# in case where we are installing the prjconfig.sh has to be located in the install directory
if [ ! -f "$CONFIGDIRABS/prjconfig.sh" -a ! -f "$SCRIPTDIR/prjconfig.sh" ]; then
	echo ''
	echo 'WARNING: project specific config file not found'
	echo ' looked in ['$CONFIGDIRABS/prjconfig.sh']'
	echo ' looked in ['$SCRIPTDIR/prjconfig.sh']'
	echo ''
fi

if [ -f "$CONFIGDIRABS/prjconfig.sh" ]; then
	if [ $PRINT_DBG -eq 1 ]; then
		echo "loading $CONFIGDIRABS/prjconfig.sh"
		echo ""
	fi
	. $CONFIGDIRABS/prjconfig.sh
	PRJCONFIGPATH=$CONFIGDIRABS
	# re-evaluate WD_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetWD_PATH
elif [ -f "$PRJCONFIGPATH/prjconfig.sh" ]; then
	if [ $PRINT_DBG -eq 1 ]; then
		echo "loading $PRJCONFIGPATH/prjconfig.sh"
		echo ""
	fi
	. $PRJCONFIGPATH/prjconfig.sh
	# re-evaluate WD_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetWD_PATH
elif [ -f "$SCRIPTDIR/prjconfig.sh" ]; then
	if [ $PRINT_DBG -eq 1 ]; then
		echo "configuration/project specific $CONFIGDIRABS/prjconfig.sh not found!"
		echo "loading $SCRIPTDIR/prjconfig.sh"
		echo ""
	fi
	. $SCRIPTDIR/prjconfig.sh
	PRJCONFIGPATH=$SCRIPTDIR
	# re-evaluate WD_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetWD_PATH
fi

SetBindir
SetBinary
TestExecWdBinaries
SetupTestExe

if [ -z "${PID_FILE}" ]; then
	PID_FILE=$PROJECTDIR/$LOGDIR/$SERVERNAME.PID
fi

if [ -z "${ServerMsgLog}" ]; then
	ServerMsgLog=$PROJECTDIR/$LOGDIR/server.msg
fi
if [ -z "${ServerErrLog}" ]; then
	ServerErrLog=$PROJECTDIR/$LOGDIR/server.err
fi

# check if WD_ROOT is already set and if so do not overwrite it but warn about
if [ $isWindows -eq 1 ]; then
	locWD_ROOT=${PROJECTDIRNT};
else
	locWD_ROOT=${PROJECTDIR};
fi
if [ -z "$WD_ROOT"  ]; then
	WD_ROOT=$locWD_ROOT;
else
	# warn only if the root dir is not the same
	if [ "$WD_ROOT" != "$locWD_ROOT" ]; then
		echo "WARNING: WD_ROOT already set to ["$WD_ROOT"] but it should be ["$locWD_ROOT"]"
	fi;
fi

export BINDIR BINDIRABS CONFIGDIR CONFIGDIRABS CURSYSTEM HOSTNAME WD_LIBDIR LOGDIR PRJ_DESCRIPTION PROJECTDIR PROJECTDIRABS PROJECTNAME SCRIPTDIR SERVERNAME TARGZNAME WD_PATH WD_ROOT

# for debugging only
if [ $PRINT_DBG -eq 1 ]; then
	for varname in PID_FILE BINDIR BINDIRABS CONFIGDIR CONFIGDIRABS CURSYSTEM HOSTNAME DOMAIN LOGDIR ServerMsgLog ServerErrLog OSREL OSTYPE PATH LD_LIBRARY_PATH PERFTESTDIR PRJCONFIGPATH PRJ_DESCRIPTION PROJECTDIRABS PROJECTDIR PROJECTDIRNT PROJECTNAME RUN_USER RUN_SERVICE SCRIPTDIR SERVERNAME PROJECTSRCDIR SYS_TMP TARGZNAME TEST_NAME TEST_EXE USR_TMP WD_LIBDIR WD_PATH WD_ROOT APP_NAME WDA_BIN WDA_BINABS WDS_BIN WDS_BINABS; do
		locVar="echo $"$varname;
		printf "%-16s: [%s]\n" $varname "`eval $locVar`"
	done
fi
