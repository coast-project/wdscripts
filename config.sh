#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
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
############################################################################

if [ "$1" = "-D" ]; then
	PRINT_DBG=1
	shift
else
	PRINT_DBG=0
fi

if [ $PRINT_DBG -eq 1 ]; then echo 'value of mypath before setting ['$mypath']'; fi
if [ $PRINT_DBG -eq 1 ]; then
	echo 'arg0 is ['$0']'
	echo 'basename of arg0 is ['`basename $0`']'
fi
if [ `basename $0` == "config.sh" ]; then
	# check if the caller already used an absolute path to start this script
	DNAM=`dirname $0`

	if [ "$DNAM" = "${DNAM#/}" ]; then
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

if [ -n "$DEV_HOME" -a "${PROJECTDIR#${myDEV_HOME}}" = "${PROJECTDIR}" -a "${PROJECTDIRABS#${myDEV_HOME}}" = "${PROJECTDIRABS}" ]; then
	echo ''
	echo 'WARNING: DEV_HOME already set to ['$DEV_HOME'] but projectdir is ['$PROJECTDIR']'
	echo ''
fi

# get projectname from projectdirectory, should be the last path segment
PROJECTNAME=${PROJECTDIR##*/}

# needed in deployable version, points to the directory where wd-binaries are in
BINDIR=`cd $PROJECTDIR/bin 2>/dev/null && pwd`

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

function SetWD_PATH
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
	#		if [ "${segname}" != "." -a -d "${PROJECTDIR}/${segname}" ]; then
			if [ -d "${segname}" ]; then
				if [ $PRINT_DBG -eq 1 ]; then echo "found valid config path ["${segname}"]"; fi
				if [ $PRINT_DBG -eq 1 ]; then echo "wd-path before ["$WD_PATH"]"; fi
				appendPath "WD_PATH" ":" "${segname}";
				if [ -z "$CONFIGDIR" ]; then
					CONFIGDIR=${segname};
				fi
			fi
		done;

		# if someone would better like to use the path found in IntWD_PATH instead of the existing
		#  path in WD_PATH he could add a switch to enable the following code
		if [ 1 -eq 0 ]; then
			prependPath "WD_PATH" ":" "${IntWD_PATH}"
			CONFIGDIR=${IntWD_PATH};
		fi
	fi
	CONFIGDIRABS=${PROJECTDIR}/${CONFIGDIR};
}

# set the WD_PATH
SetWD_PATH

# try to find out on which machine we are running
HOSTNAME=`(uname -n) 2>/dev/null` || HOSTNAME="unkown"

# check if bindir could be found, when started in development env this is probably not set
# and this is why I use some 'hard' assumptions
if [ -n "$DEV_HOME" -a -z "$BINDIR" ]; then
	# BINDIR not set, use development defaults
	BINDIR=${DEV_HOME}/WWW/wdapp
fi
if [ -n "$BINDIR" ]; then
	BINDIR=`cd ${BINDIR} 2>/dev/null && pwd`
	WDS_BIN=${BINDIR}/wdapp${EXEEXT}
	WDA_BIN=${BINDIR}/wdapp${EXEEXT}
fi

if [ "$1" = "quantify" ]; then
	export QUANTIFYOPTIONS="-max_threads=500 $QUANTIFYOPTIONS"
	WDS_BIN=${WDS_BIN}.quantify
	WDA_BIN=${WDA_BIN}.quantify
elif [ "$1" = "purify" ]; then
	export PURIFYOPTIONS="-max_threads=500 $PURIFYOPTIONS"
	WDS_BIN=${WDS_BIN}.purify
	WDA_BIN=${WDA_BIN}.purify
fi

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

SERVERNAME=$PROJECTNAME
PRJ_DESCRIPTION="itopia $SERVERNAME"
TARGZNAME=$SERVERNAME.tgz
ALL_CONFIGS="itopiaOnly"

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

# test if the wdapp executable exists, or clear the var if not
if [ ! -x ${WDA_BIN} ]; then
	WDA_BIN=
fi

# test if the server executable exists, or clear the var if not
if [ ! -x ${WDS_BIN} ]; then
	WDS_BIN=
fi

if [ -z "${PID_FILE}" ]; then
	PID_FILE=$PROJECTDIR/$LOGDIR/$SERVERNAME.PID
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

export ALL_CONFIGS BINDIR CONFIGDIR CONFIGDIRABS CURSYSTEM HOSTNAME WD_LIBDIR LOGDIR PRJ_DESCRIPTION PROJECTDIR PROJECTDIRABS PROJECTNAME SCRIPTDIR SERVERNAME TARGZNAME WD_PATH WD_ROOT

# for debugging only
if [ $PRINT_DBG -eq 1 ]; then
	echo "PID-file:     $PID_FILE"
	echo "allconfigs:   $ALL_CONFIGS"
	echo "dfltconfig:   $DEF_CONF"
	echo "bindir:       $BINDIR"
	echo "configdir:    $CONFIGDIR"
	echo "confgdirabs:  $CONFIGDIRABS"
	echo "cursystem:    $CURSYSTEM"
	echo "hostname:     $HOSTNAME"
	echo "logdir:       $LOGDIR"
	echo "ostype:       $OSTYPE"
if [ $isWindows -eq 1 ]; then
	echo "path:         $PATH"
else
	echo "ld_libpath:   $LD_LIBRARY_PATH"
fi
	echo "perftest:     $PERFTESTDIR"
	echo "prjconfig in: $PRJCONFIGPATH"
	echo "prjdesc:      $PRJ_DESCRIPTION"
	echo "prjdir-abs:   $PROJECTDIRABS"
	echo "projectdir:   $PROJECTDIR"
	echo "projectname:  $PROJECTNAME"
	echo "scriptdir:    $SCRIPTDIR"
	echo "servername:   $SERVERNAME"
	echo "sourcedir:    $PROJECTSRCDIR"
	echo "sys-tmpdir:   $SYS_TMP"
	echo "tar-gz-name:  $TARGZNAME"
	echo "usr-tmpdir:   $USR_TMP"
	echo "wd_libdir:    $WD_LIBDIR"
	echo "wd_path:      $WD_PATH"
	echo "wd_root:      $WD_ROOT"
	echo "wdapp:        $WDA_BIN"
	echo "wdserver:     $WDS_BIN"
fi
