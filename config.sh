#!/bin/sh
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
	shift 1
fi
PRINT_DBG=${PRINT_DBG:=0}
export PRINT_DBG

do_quantify=0;
do_purify=0;
if [ "$1" = "quantify" ]; then do_quantify=1; fi
if [ "$1" = "purify" ]; then do_purify=1; fi

set -h	# remember functions
hash -r
hash basename dirname sed cut tr echo printf

if [ ! `basename $0` = "config.sh" ]; then
	test $PRINT_DBG -ge 1 && echo "I got sourced from within [$0]"
fi

configScriptName=config.sh
# try to select first valid script directory
for myd in `dirname $0` ${SCRIPTDIR} $mypath; do
	test $PRINT_DBG -ge 2 && echo "testing directory [$myd]"
	test ! -f $myd/$configScriptName && continue
	scdir=$myd; break;
done

if [ -z "${scdir}" -o "${scdir}" = "." ]; then
	scdir=`find . -follow -name $configScriptName 2>/dev/null | head -1 | tr -d '\n'`
	test -z "${scdir}" && scdir="`type -fP $configScriptName`"
	test -n "${scdir}" && scdir="`cd \`dirname $scdir\` && pwd`";
fi
SCRIPTDIR=`cd $scdir && pwd`

# load os-specific settings and functions
. ${SCRIPTDIR}/sysfuncs.sh

# points to the directory where the scripts reside
SCRIPTDIR=`deref_links "${SCRIPTDIR}"`
SCRIPTDIRABS=`makeAbsPath "${SCRIPTDIR}"`

# the directory where all starts is where we call the script from
# here we can find project specific directories, eg. config, Docs etc.
PROJECTDIR=`PATH=/usr/bin:/bin:$PATH; pwd`
PROJECTDIRABS=${PROJECTDIR}
isAbsPath ${PROJECTDIRABS} || PROJECTDIRABS=`makeAbsPath "${PROJECTDIR}"`

if [ ${isWindows} -eq 1 ]; then
	# get projectdir in native NT drive:path notation
	getDosDir "${PROJECTDIR}" "PROJECTDIRNT"
	getUnixDir "${PROJECTDIR}" "PROJECTDIR"
	getUnixDir "${SCRIPTDIR}" "SCRIPTDIR"
fi

if [ -n "$DEV_HOME" ]; then
	relativeToProjectdir="`relpath \"${DEV_HOME}\" \"${PROJECTDIR}\"`"
	if [ "${relativeToProjectdir}" = "${PROJECTDIR}" ]; then
		# path is not related
		echo ''
		echo 'WARNING: DEV_HOME already set to ['$DEV_HOME'] but projectdir is ['$PROJECTDIR']'
		echo ''
	fi
fi

SetupLogDir()
{
	LOGDIR=`relpath "${LOGDIR:-.}" "${PROJECTDIRABS}"`;
	LOGDIRABS=`makeAbsPath "${LOGDIR:-.}"`
}

SetCOAST_PATH()
{
	# check if we have a wd_path yet
	if [ -z "$COAST_PATH" -a -z "$WD_PATH" ]; then
		# we do not have a coast_path, copy from IntCOAST_PATH or use . if empty
		COAST_PATH="`appendPathEx \"$COAST_PATH\" \":\" \"${IntCOAST_PATH:-.}\"`"
		CONFIGDIR=${IntCOAST_PATH:-.};
	else
		# we have a coast_path, copy first existing segment into CONFIGDIR
		tmpCOAST_PATH=${COAST_PATH:-${WD_PATH}};
		CONFIGDIR="";
		COAST_PATH="";
		oldifs="${IFS}";
		IFS=":";
		for segname in ${tmpCOAST_PATH}; do
			IFS=$oldifs;
			if [ $PRINT_DBG -ge 2 ]; then echo "segment is ["$segname"]"; fi
			if [ -d "${segname}" ]; then
				if [ $PRINT_DBG -ge 2 ]; then echo "found valid config path ["${segname}"]"; fi
				if [ $PRINT_DBG -ge 2 ]; then echo "coast_path before ["$COAST_PATH"]"; fi
				COAST_PATH="`appendPathEx \"$COAST_PATH\" \":\" \"${segname}\"`";
				if [ -z "$CONFIGDIR" ]; then
					CONFIGDIR=${segname};
				fi
			fi
		done;
		if [ -z "$CONFIGDIR" ]; then
			CONFIGDIR=".";
		fi

		# if someone would better like to use the path found in IntCOAST_PATH instead of the existing
		#  path in COAST_PATH he could add a switch to enable the following code
		if [ 1 -eq 0 ]; then
			prependPath "COAST_PATH" ":" "${IntCOAST_PATH}"
			CONFIGDIR=${IntCOAST_PATH};
		fi
	fi
	WD_PATH=$COAST_PATH
	CONFIGDIRABS=`makeAbsPath "${PROJECTDIR}/${CONFIGDIR}"`
}

# param 1: use specific binary to search/test for, default ${APP_NAME}
# param(s) 2.. directories in which to search
#
# output: echo path to binary if any
GetBindir()
{
	binarytosearch=${1};
	test -z "${binarytosearch}" && return
	test $# -gt 1 || return 0;
	shift 1
	candidates=`find $@ -type f -name ${binarytosearch} 2>/dev/null | head -1`;
	test -z "${candidates}" && return
	echo "`dirname ${candidates}`";
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
		QUANTIFYOPTIONS="-max_threads=500 $QUANTIFYOPTIONS"
		export QUANTIFYOPTIONS
		WDS_BIN=${WDS_BIN}.quantify
		WDA_BIN=${WDA_BIN}.quantify
	elif [ $do_purify -eq 1 ]; then
		PURIFYOPTIONS="-max_threads=500 $PURIFYOPTIONS"
		export PURIFYOPTIONS
		WDS_BIN=${WDS_BIN}.purify
		WDA_BIN=${WDA_BIN}.purify
	fi
}

TestExecWdBinaries()
{
	# test if the wdapp executable exists, or clear the var if not
	test -n "${WDA_BIN}" && test -x ${WDA_BIN} || WDA_BIN=
	test -n "${WDA_BINABS}" && test -x ${WDA_BINABS} || WDA_BINABS=
	# test if the server executable exists, or clear the var if not
	test -n "${WDS_BIN}" && test -x ${WDS_BIN} || WDS_BIN=
	test -n "${WDS_BINABS}" && test -x ${WDS_BINABS} || WDS_BINABS=
}

# param(s): specify the executables to process
SetupLDPath()
{
	locLdPathVar=LD_LIBRARY_PATH;
	if [ $isWindows -eq 1 ]; then
		locLdPathVar="PATH";
	fi
	valueOfLdVar="echo $"${locLdPathVar};
	valueOfLdVar="`eval $valueOfLdVar`";
	valueOfLdVar="`deleteFromPathEx \"${valueOfLdVar}\" \":\" \"${COAST_LIBDIR:-${WD_LIBDIR:-.}}\"`"
	locBinPath="";
	locLastBinPath="";
	sldpProcessedBins="";
	for binname in $@; do
		if [ -n "${binname}" ]; then
			existInPath "${sldpProcessedBins}" ":" "${binname}" && continue;
			sldpProcessedBins="`appendPathEx \"${sldpProcessedBins}\" \":\" \"${binname}\"`";
			dname="`dirname ${binname}`";
			locBinPath="`echo ${dname} | sed \"s|[_.]*${OSREL}\$||\"`";
			locBinPath=${locBinPath:=./};
			if [ -n "${locBinPath}" -a "${locBinPath}" != "${locLastBinPath}" -a -d "${locBinPath}" ]; then
				locLastBinPath=${locBinPath};
				locLdSearchFile=${locBinPath}/.ld-search-path
				if [ $PRINT_DBG -ge 2 ]; then echo "testing in dir [${locBinPath}], file [${locLdSearchFile}]"; fi;
				if [ -r ${locLdSearchFile} ]; then
					valueOfLdVar="`prependPathEx \"${valueOfLdVar}\" \":\" \"\`cat ${locLdSearchFile}\`\"`"
				fi;
			fi;
		fi;
	done;
	valueOfLdVar="`cleanPathEx \"${valueOfLdVar}\" \":\"`"
	valueOfLdVar="`prependPathEx \"${valueOfLdVar}\" \":\" \"${COAST_LIBDIR:-${WD_LIBDIR:-.}}\"`"
	if [ $PRINT_DBG -ge 2 ]; then
		echo "${locLdPathVar} is now [${valueOfLdVar}]"
	fi;
	eval ${locLdPathVar}="${valueOfLdVar}"
	export ${locLdPathVar}
}

# get projectname from projectdirectory, should be the last path segment
PROJECTNAME=`echo ${PROJECTDIR} | sed 's|^.*/||'`

# directory name of the log directory, may be overwritten in the project specific prjconfig.sh
LOGDIR="`SearchJoinedDir \"$PROJECTDIR\" \"$PROJECTNAME\" \"log\"`"
test -z "${LOGDIR}" && LOGDIR=.;
LOGDIRABS="${LOGDIR}"

SetupLogDir

# directory name of the perftest directory, if any
PERFTESTDIR="`SearchJoinedDir \"$PROJECTDIR\" \"$PROJECTNAME\" \"perftest\"`"

# directory name of the source directory
PROJECTSRCDIR="`SearchJoinedDir \"$PROJECTDIR\" \"$PROJECTNAME\" \"src\"`"

# directory name of the config directory
IntCOAST_PATH="`SearchJoinedDir \"$PROJECTDIR\" \"$PROJECTNAME\" \"config\"`"

# try to find out on which machine we are running
HOSTNAME=`uname -n 2>/dev/null` || HOSTNAME="unkown"
test -n "${HOSTNAME}" && DOMAIN=`getdomain "${HOSTNAME}"`

# set the COAST_PATH
SetCOAST_PATH

# set default binary name to execute either in foreground or background
# in case of WebDisplay2 this is almost always wdapp
APP_NAME=${APP_NAME:-wdapp}

# needed in deployable version, points to the directory where wd-binaries are in
BINDIR="`SearchJoinedDir \"$PROJECTDIR\" \"bin\" \"${OSREL}\" \"\" \"0\"`"
if [ -z "${BINDIR}" ]; then
	BINDIR="`SearchJoinedDir \"$PROJECTDIR\" \"bin\" \"${CURSYSTEM}\" \"\" \"0\"`"
	if [ -z "${BINDIR}" ]; then
		BINDIR="`SearchJoinedDir \"$PROJECTDIR\" \"bin\" \"\" \"\" \"0\"`"
	fi;
fi;

myLIBDIR="`SearchJoinedDir \"$PROJECTDIR\" \"lib\" \"${OSREL}\" \"\" \"0\"`"
if [ -z "${myLIBDIR}" ]; then
	myLIBDIR="`SearchJoinedDir \"$PROJECTDIR\" \"lib\" \"${CURSYSTEM}\" \"\" \"0\"`"
	if [ -z "${myLIBDIR}" ]; then
		myLIBDIR="`SearchJoinedDir \"$PROJECTDIR\" \"lib\" \"\" \"\" \"0\"`"
	fi;
fi;

# directory where WD-Libs are in
if [ -z "${myLIBDIR}" ]; then
	# now check if COAST_LIBDIR is already set
	if [ -z "${COAST_LIBDIR}" -a -z "${WD_LIBDIR}" ]; then
		if [ -n "$DEV_HOME" ]; then
			# finally use $DEV_HOME/lib
			myLIBDIR="${DEV_HOME}/lib"
		fi
	else
		myLIBDIR="${COAST_LIBDIR:-${WD_LIBDIR}}"
	fi
fi
if [ -n "${myLIBDIR}" ]; then
	if [ -n "${myLIBDIR}" -a ! -d "${myLIBDIR}" ]; then
		mkdir -p "${myLIBDIR}";
	fi;
	COAST_LIBDIR="`makeAbsPath \"${myLIBDIR}\"`"
fi
WD_LIBDIR="$COAST_LIBDIR"
if [ -z "$COAST_LIBDIR" ]; then
	if [ $PRINT_DBG -ge 2 ]; then
		echo 'WARNING: could not find a library directory, looked in:'
		echo 'PROJECTDIR/lib: ['${PROJECTDIR}/lib']'
		echo 'COAST_LIBDIR  : ['${COAST_LIBDIR}']'
		test -n "$DEV_HOME" && echo 'DEV_HOME/lib  : ['${DEV_HOME}/lib']'
	fi;
fi

if [ -z "${SERVERNAME}" ]; then
	SERVERNAME=$PROJECTNAME
fi;

# in case where we are installing the prjconfig.sh has to be located in the install directory
if [ ! -f "$CONFIGDIRABS/prjconfig.sh" -a ! -f "$SCRIPTDIR/prjconfig.sh" ]; then
	echo ''
	echo 'WARNING: project specific config file not found'
	echo ' looked in ['$CONFIGDIRABS/prjconfig.sh']'
	echo ' looked in ['$SCRIPTDIR/prjconfig.sh']'
	echo ''
fi

if [ -f "$CONFIGDIRABS/prjconfig.sh" ]; then
	if [ $PRINT_DBG -ge 1 ]; then
		echo "loading $CONFIGDIRABS/prjconfig.sh"
		echo ""
	fi
	. $CONFIGDIRABS/prjconfig.sh
	PRJCONFIGPATH=$CONFIGDIRABS
	# re-evaluate COAST_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetCOAST_PATH
elif [ -f "$PRJCONFIGPATH/prjconfig.sh" ]; then
	if [ $PRINT_DBG -ge 1 ]; then
		echo "loading $PRJCONFIGPATH/prjconfig.sh"
		echo ""
	fi
	. $PRJCONFIGPATH/prjconfig.sh
	# re-evaluate COAST_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetCOAST_PATH
else
	if [ $PRINT_DBG -ge 1 ]; then
		echo "configuration/project specific $CONFIGDIRABS/prjconfig.sh not found!"
		echo "loading $SCRIPTDIR/prjconfig.sh"
		echo ""
	fi
fi

PRJ_DESCRIPTION="${PRJ_DESCRIPTION:-$SERVERNAME}"
test -z "${BINDIR}" && BINDIR=`GetBindir ${APP_NAME} ${PROJECTDIR}*bin* ${PROJECTDIR}`
test -n "${BINDIR}" && BINDIRABS=`makeAbsPath "${BINDIR}"`
SetBinary
TestExecWdBinaries
SetupLDPath ${WDA_BINABS} ${WDS_BINABS}
SetupLogDir

# param $1: path or name to append
# output: absolute path/name
appendToLogdirAbsolute()
{
	logdir=${LOGDIRABS};
	test -z "${logdir}" && logdir=.;
	echo "${logdir}/${1}"
}

if [ -z "${PID_FILE}" ]; then
	PID_FILE=`appendToLogdirAbsolute ${SERVERNAME}.PID`
fi
if [ -z "${ServerMsgLog}" ]; then
	ServerMsgLog=`appendToLogdirAbsolute server.msg`
fi
if [ -z "${ServerErrLog}" ]; then
	ServerErrLog=`appendToLogdirAbsolute server.err`
fi

# check if COAST_ROOT is already set and if so do not overwrite it but warn about
if [ $isWindows -eq 1 ]; then
	locCOAST_ROOT=${PROJECTDIRNT};
else
	locCOAST_ROOT=${PROJECTDIR};
fi
if [ -z "$COAST_ROOT" -a -z "$WD_ROOT" ]; then
	COAST_ROOT=$locCOAST_ROOT;
else
	# warn only if the root dir is not the same
	if [ "$COAST_ROOT" != "$locCOAST_ROOT" -o "$WD_ROOT" != "$locCOAST_ROOT" ]; then
		echo "WARNING: COAST_ROOT already set to ["$COAST_ROOT"] but it should be ["$locCOAST_ROOT"]"
	fi;
fi
WD_ROOT=$COAST_ROOT

KEEP_SCRIPT=${SCRIPTDIR:-.}/keepwds.sh;
START_SCRIPT=${SCRIPTDIR:-.}/startwds.sh;
STOP_SCRIPT=${SCRIPTDIR:-.}/stopwds.sh;
KEEPPIDFILE=${LOGDIRABS:-.}/.$SERVERNAME.keepwds.pid
RUNUSERFILE=${LOGDIRABS:-.}/.RunUser

versionFile=${CONFIGDIRABS:-.}/Version.any
PROJECTVERSION=""
if [ -f $versionFile ]; then
	VERSIONFILE=$versionFile;
	PROJECTVERSION="`sed -n 's/^.*Release[ \t]*//p' $versionFile | tr -d '\"\t '`.`sed -n 's/^.*Build[ \t]*//p' $versionFile | tr -d '\"\t '`"
fi

test -n "COAST_DOLOG" && WD_DOLOG=${COAST_DOLOG}
test -n "COAST_LOGONCERR" && WD_LOGONCERR=${COAST_LOGONCERR}

variablesToExport="BINDIR BINDIRABS CONFIGDIR CONFIGDIRABS LOGDIR LOGDIRABS PERFTESTDIR PRJCONFIGPATH PROJECTDIR PROJECTDIRABS PROJECTDIRNT PROJECTNAME PROJECTSRCDIR SCRIPTDIR SCRIPTDIRABS"
variablesToExport="$variablesToExport HOSTNAME DOMAIN PRJ_DESCRIPTION SERVERNAME"
variablesToExport="$variablesToExport INSTALLFILES PROJECTVERSION VERSIONFILE KEEP_SCRIPT START_SCRIPT STOP_SCRIPT KEEPPIDFILE RUNUSERFILE PID_FILE"
variablesToExport="$variablesToExport COAST_LIBDIR COAST_ROOT COAST_PATH"
variablesToExport="$variablesToExport COAST_DOLOG COAST_LOGONCERR COAST_LOGONCERR_WITH_TIMESTAMP COAST_USE_MMAP_STREAMS COAST_TRACE_INITFINIS COAST_TRACE_STATICALLOC COAST_TRACE_STORAGE"

export $variablesToExport

# for debugging only
if [ $PRINT_DBG -ge 1 ]; then
	variablesToPrint="$sysfuncsExportvars $variablesToExport ServerMsgLog ServerErrLog PATH LD_LIBRARY_PATH RUN_ATTACHED_TO_GDB RUN_USER RUN_SERVICE RUN_SERVICE_CFGFILE APP_NAME WDA_BIN WDA_BINABS WDS_BIN WDS_BINABS"
	variablesToPrint="`echo $variablesToPrint | tr ' ' '\n' | sort | uniq | tr '\n' ' '`"
	for varname in $variablesToPrint; do
		printEnvVar ${varname};
	done
fi
