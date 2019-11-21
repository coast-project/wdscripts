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
PRINT_DBG=${PRINT_DBG:-0}
export PRINT_DBG

# unset all functions to remove potential definitions
# generated using $> sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p' config.sh | grep -v "\$$"
unset -f upwardSearchScriptpath
unset -f SetupLogDir
unset -f SetCOAST_PATH
unset -f GetBindir
unset -f SetBinary
unset -f TestExecWdBinaries
unset -f SetupLDPath
unset -f appendToLogdirAbsolute

do_quantify=0;
do_purify=0;
if [ "$1" = "quantify" ]; then do_quantify=1; fi
if [ "$1" = "purify" ]; then do_purify=1; fi

hash -r
hash basename dirname sed cut tr echo printf
startpath="$(pwd)"

configScriptName=config.sh
configScriptDir="$(dirname "$0")"
if [ "$(basename "$0")" != "$configScriptName" ]; then
	[ "${PRINT_DBG:-0}" -ge 1 ] && echo "I got sourced from within [$0]"
	[ -z "${mypath:-}" ] && { echo "\$mypath variable is unset but needs to be set when $configScriptName gets sourced, aborting!"; return 1; }
	configScriptDir="${mypath}"
fi

upwardSearchScriptpath()
{
	testScriptName="${1}";
	shift 1;
	for myd in "$@"; do
		while : ; do
		    myd_stripped="${myd%%/}"
		    for theScript in "$myd_stripped"/*scripts*/"$testScriptName" "$myd_stripped"/"$testScriptName"; do
		        [ -e "$theScript" ] || [ -L "$theScript" ] || continue
				dirname "$theScript";
				return 0;
		    done
	    	[ "$myd" = "/" ] && break;
			myd="$(cd "$myd_stripped"/.. >/dev/null 2>&1 && pwd)"
	    done;
	done
}

scdir_candidates="${startpath:-} ${configScriptDir:-} ${SCRIPTDIR:-} ${mypath:-}"
# shellcheck disable=SC2086
SCRIPTDIR="$(upwardSearchScriptpath sysfuncs.sh $scdir_candidates)"
[ -n "$SCRIPTDIR" ] || { printf "Unable to locate scripts directory containing 'sysfuncs.sh', aborting!\n\
Searched directories [%s] and upwards.\n" "$scdir_candidates"; exit 2; }

# fail in case of sourcing errors
set -e
# load os-specific settings and functions
# shellcheck source=./sysfuncs.sh
. "${SCRIPTDIR}"/sysfuncs.sh
set +e

scriptdir_name="$(basename "$SCRIPTDIR")"
PROJECTDIR="$(searchBaseDirUp "$SCRIPTDIR" "${scriptdir_name}" "$startpath")"
# searchBaseDirUp already returns an absolute path
PROJECTDIRABS=${PROJECTDIR}

# points to the directory where the scripts reside
# shellcheck disable=SC2034
SCRIPTDIRABS=$(makeAbsPath "${SCRIPTDIR}" "" "$PROJECTDIRABS")

if [ "${isWindows:-0}" -eq 1 ]; then
	# get projectdir in native NT drive:path notation
	getDosDir "${PROJECTDIR}" "PROJECTDIRNT"
	getUnixDir "${PROJECTDIR}" "PROJECTDIR"
	getUnixDir "${SCRIPTDIR}" "SCRIPTDIR"
fi

if [ -n "$DEV_HOME" ]; then
	relativeToProjectdir="$(relpath "${DEV_HOME}" "${PROJECTDIR}")"
	if [ "${relativeToProjectdir}" = "${PROJECTDIR}" ]; then
		# path is not related
		echo ""
		echo "WARNING: DEV_HOME already set to [$DEV_HOME] but projectdir is [$PROJECTDIR]"
		echo ""
	fi
fi

SetupLogDir()
{
	LOGDIR=$(relpath "${LOGDIR:-$startpath}" "${PROJECTDIRABS}");
	LOGDIRABS=$(makeAbsPath "${LOGDIR}" "" "$PROJECTDIRABS")
}

SetCOAST_PATH()
{
	__trace_on
	# check if we have a wd_path yet
	if [ -z "$COAST_PATH" ] && [ -z "$WD_PATH" ]; then
		# we do not have a coast_path, copy from IntCOAST_PATH or use . if empty
		COAST_PATH="$(appendPathEx "$COAST_PATH" ":" "${IntCOAST_PATH:-.}")"
		CONFIGDIR=${IntCOAST_PATH:-.};
	else
		# we have a coast_path, copy first existing segment into CONFIGDIR
		tmpCOAST_PATH=${COAST_PATH:-${WD_PATH}};
		coastpath_and_configdir="$(
			cd "$PROJECTDIRABS";
			oldifs="${IFS}";
			IFS=":";
			for segname in ${tmpCOAST_PATH}; do
				IFS=$oldifs;
				if [ $PRINT_DBG -ge 2 ]; then echo "segment is [$segname]"; fi
				if [ -d "${segname}" ]; then
					if [ $PRINT_DBG -ge 2 ]; then echo "found valid config path [${segname}]"; fi
					if [ $PRINT_DBG -ge 2 ]; then echo "coast_path before [$COAST_PATH]"; fi
					COAST_PATH="$(appendPathEx "$COAST_PATH" ":" "${segname}")";
					if [ -z "$CONFIGDIR" ]; then
						CONFIGDIR=${segname};
					fi
				fi
			done;
			echo "$COAST_PATH|$CONFIGDIR";
		)"
		COAST_PATH="$(getCSVValue "$coastpath_and_configdir" 1 "|")";
		CONFIGDIR="$(getCSVValue "$coastpath_and_configdir" 2 "|")";
		if [ -z "$CONFIGDIR" ]; then
			CONFIGDIR=".";
		fi
	fi
	WD_PATH=$COAST_PATH
	CONFIGDIRABS=$(makeAbsPath "${PROJECTDIR%%/}/${CONFIGDIR%%/}" "" "$PROJECTDIRABS")
	__trace_off
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
	candidates=$(find "$@" -maxdepth 2 -type f -name "${binarytosearch}" 2>/dev/null | head -1);
	test -z "${candidates}" && return
	dirname "${candidates}";
}

SetBinary()
{
	__trace_on
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
	__trace_off
}

TestExecWdBinaries()
{
	__trace_on
	# test if the wdapp executable exists, or clear the var if not
	if [ -n "${WDA_BIN}" ]; then
		[ -x "${PROJECTDIRABS%%/}/${WDA_BIN}" ] || WDA_BIN=
	fi
	if [ -n "${WDA_BINABS}" ]; then
		[ -x "${WDA_BINABS}" ] || WDA_BINABS=
	fi
	# test if the server executable exists, or clear the var if not
	if [ -n "${WDS_BIN}" ]; then
		[ -x "${PROJECTDIRABS%%/}/${WDS_BIN}" ] || WDS_BIN=
	fi
	if [ -n "${WDS_BINABS}" ]; then
		[ -x "${WDS_BINABS}" ] || WDS_BINABS=
	fi
	__trace_off
}

# param(s): specify the executables to process
SetupLDPath()
{
	locLdPathVar=LD_LIBRARY_PATH;
	if [ "${isWindows:-0}" -eq 1 ]; then
		locLdPathVar="PATH";
	fi
	valueOfLdVar="echo $"${locLdPathVar};
	valueOfLdVar="$(eval "$valueOfLdVar")";
	valueOfLdVar="$(deleteFromPathEx "${valueOfLdVar}" ":" "${COAST_LIBDIR:-${WD_LIBDIR:-.}}")"
	locBinPath="";
	locLastBinPath="";
	sldpProcessedBins="";
	valueOfLdVar=$(
		cd "$PROJECTDIR";
		for binname in "$@"; do
			if [ -n "${binname}" ]; then
				existInPath "${sldpProcessedBins}" ":" "${binname}" && continue;
				sldpProcessedBins="$(appendPathEx "${sldpProcessedBins}" ":" "${binname}")";
				dname="$(dirname ${binname})";
				locBinPath="$(echo "${dname}" | sed "s|[_.]*${OSREL}\$||" )";
				locBinPath=${locBinPath:=./};
				if [ -n "${locBinPath}" ] && [ "${locBinPath}" != "${locLastBinPath}" ] && [ -d "${locBinPath}" ]; then
					locLastBinPath=${locBinPath};
					locLdSearchFile=${locBinPath}/.ld-search-path
					if [ $PRINT_DBG -ge 2 ]; then echo "testing in dir [${locBinPath}], file [${locLdSearchFile}]"; fi;
					if [ -r ${locLdSearchFile} ]; then
						valueOfLdVar="$(prependPathEx "${valueOfLdVar}" ":" "$(cat ${locLdSearchFile})")"
					fi;
				fi;
			fi;
		done;
		echo "$valueOfLdVar";
	)
	valueOfLdVar="$(cleanPathEx "${valueOfLdVar}" ":")"
	valueOfLdVar="$(prependPathEx "${valueOfLdVar}" ":" "${COAST_LIBDIR:-${WD_LIBDIR:-.}}")"
	if [ $PRINT_DBG -ge 2 ]; then
		echo "${locLdPathVar} is now [${valueOfLdVar}]"
	fi;
	eval "${locLdPathVar}=${valueOfLdVar}"
	export "${locLdPathVar?}"
}

# get projectname from projectdirectory, should be the last path segment
PROJECTNAME=$(basename "${PROJECTDIR}")
[ "$PROJECTNAME" != "/" ] || PROJECTNAME=RoOtPrOjEcT;

# directory name of the log directory, may be overwritten in the project specific prjconfig.sh
LOGDIR="$(SearchJoinedDir "$PROJECTDIR" "$PROJECTNAME" "log")"
if [ -z "${LOGDIR}" ]; then
	if [ "$PROJECTDIR" = "/" ]; then
		LOGDIR=$startpath;
	else
		LOGDIR=$PROJECTDIR;
	fi
fi

SetupLogDir

# directory name of the perftest directory, if any
# shellcheck disable=SC2034
PERFTESTDIR="$(SearchJoinedDir "$PROJECTDIR" "$PROJECTNAME" "perftest")"

# directory name of the source directory
# shellcheck disable=SC2034
PROJECTSRCDIR="$(SearchJoinedDir "$PROJECTDIR" "$PROJECTNAME" "src")"

# directory name of the config directory
IntCOAST_PATH="$(SearchJoinedDir "$PROJECTDIR" "$PROJECTNAME" "config")"

# try to find out on which machine we are running
HOSTNAME=$(uname -n 2>/dev/null) || HOSTNAME="unkown"
# shellcheck disable=SC2034
test -n "${HOSTNAME}" && DOMAIN=$(getdomain "${HOSTNAME}")

# set the COAST_PATH
SetCOAST_PATH

# set default binary name to execute either in foreground or background
# in case of WebDisplay2 this is almost always wdapp
APP_NAME=${APP_NAME:-wdapp}

# needed in deployable version, points to the directory where wd-binaries are in
BINDIR="$(SearchJoinedDir "$PROJECTDIR" "bin" "${OSREL}" "" "0")"
if [ -z "${BINDIR}" ]; then
	BINDIR="$(SearchJoinedDir "$PROJECTDIR" "bin" "${CURSYSTEM}" "" "0")"
	if [ -z "${BINDIR}" ]; then
		BINDIR="$(SearchJoinedDir "$PROJECTDIR" "bin" "" "" "0")"
	fi;
fi;

myLIBDIR="$(SearchJoinedDir "$PROJECTDIR" "lib" "${OSREL}" "" "0")"
if [ -z "${myLIBDIR}" ]; then
	myLIBDIR="$(SearchJoinedDir "$PROJECTDIR" "lib" "${CURSYSTEM}" "" "0")"
	if [ -z "${myLIBDIR}" ]; then
		myLIBDIR="$(SearchJoinedDir "$PROJECTDIR" "lib" "" "" "0")"
	fi;
fi;

# directory where WD-Libs are in
if [ -z "${myLIBDIR}" ]; then
	# now check if COAST_LIBDIR is already set
	if [ -z "${COAST_LIBDIR}" ] && [ -z "${WD_LIBDIR}" ]; then
		if [ -n "$DEV_HOME" ]; then
			# finally use $DEV_HOME/lib
			myLIBDIR="${DEV_HOME}/lib"
		fi
	else
		myLIBDIR="${COAST_LIBDIR:-${WD_LIBDIR}}"
	fi
fi
if [ -n "${myLIBDIR}" ]; then
	(
		cd "$PROJECTDIRABS";
		if [ -n "${myLIBDIR}" ] && [ ! -d "${myLIBDIR}" ]; then
			mkdir -p "${myLIBDIR}";
		fi;
	)
	COAST_LIBDIR="$(makeAbsPath "${myLIBDIR}" "" "$PROJECTDIRABS")"
fi
WD_LIBDIR="$COAST_LIBDIR"
if [ -z "$COAST_LIBDIR" ]; then
	if [ $PRINT_DBG -ge 2 ]; then
		echo "WARNING: could not find a library directory, looked in:"
		echo "PROJECTDIR/lib: [${PROJECTDIR}/lib]"
		echo "COAST_LIBDIR  : [${COAST_LIBDIR}]"
		test -n "$DEV_HOME" && echo "DEV_HOME/lib  : [${DEV_HOME}/lib]"
	fi;
fi

if [ -z "${SERVERNAME}" ]; then
	SERVERNAME=$PROJECTNAME
fi;

# in case where we are installing the prjconfig.sh has to be located in the install directory
if [ ! -f "$CONFIGDIRABS/prjconfig.sh" ] && [ ! -f "$SCRIPTDIR/prjconfig.sh" ]; then
	echo ""
	echo "WARNING: project specific config file not found"
	echo " looked in [${CONFIGDIRABS:-\$CONFIGDIRABS}/prjconfig.sh]"
	echo " looked in [${SCRIPTDIR:-\$SCRIPTDIR}/prjconfig.sh]"
	echo ""
fi

if [ -f "${CONFIGDIRABS%%/}/prjconfig.sh" ]; then
	if [ $PRINT_DBG -ge 1 ]; then
		echo "loading ${CONFIGDIRABS%%/}/prjconfig.sh"
		echo ""
	fi
	# shellcheck source=./prjconfig.sh
	. "${CONFIGDIRABS%%/}"/prjconfig.sh
	PRJCONFIGPATH=$CONFIGDIRABS
	# re-evaluate COAST_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetCOAST_PATH
elif [ -f "${PRJCONFIGPATH%%/}/prjconfig.sh" ]; then
	if [ $PRINT_DBG -ge 1 ]; then
		echo "loading ${PRJCONFIGPATH%%/}/prjconfig.sh"
		echo ""
	fi
	# shellcheck source=./prjconfig.sh
	. "${PRJCONFIGPATH%%/}"/prjconfig.sh
	# re-evaluate COAST_PATH, sets CONFIGDIR and CONFIGDIRABS again
	SetCOAST_PATH
else
	if [ $PRINT_DBG -ge 1 ]; then
		echo "configuration/project specific ${CONFIGDIRABS%%/}/prjconfig.sh not found!"
		echo "loading ${SCRIPTDIR%%/}/prjconfig.sh"
		echo ""
	fi
fi

PRJ_DESCRIPTION="${PRJ_DESCRIPTION:-$SERVERNAME}"
test -z "${BINDIR}" && BINDIR=$(GetBindir "${APP_NAME}" "${PROJECTDIR}*bin*" "${PROJECTDIR}")
test -n "${BINDIR}" && BINDIRABS=$(makeAbsPath "${BINDIR}" "" "$PROJECTDIRABS")
SetBinary
TestExecWdBinaries
SetupLDPath "${WDA_BINABS}" "${WDS_BINABS}"
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
	PID_FILE=$(appendToLogdirAbsolute "${SERVERNAME}".PID)
fi
if [ -z "${ServerMsgLog}" ]; then
	ServerMsgLog=$(appendToLogdirAbsolute server.msg)
fi
if [ -z "${ServerErrLog}" ]; then
	ServerErrLog=$(appendToLogdirAbsolute server.err)
fi

# check if COAST_ROOT is already set and if so do not overwrite it but warn about
if [ "${isWindows:-0}" -eq 1 ]; then
	# shellcheck disable=SC2153
	locCOAST_ROOT=${PROJECTDIRNT};
else
	locCOAST_ROOT=${PROJECTDIR};
fi
if [ -z "$COAST_ROOT" ] && [ -z "$WD_ROOT" ]; then
	COAST_ROOT=$locCOAST_ROOT;
else
	# warn only if the root dir is not the same
	if [ "$COAST_ROOT" != "$locCOAST_ROOT" ] || [ "$WD_ROOT" != "$locCOAST_ROOT" ]; then
		echo "WARNING: COAST_ROOT already set to [$COAST_ROOT] but it should be [$locCOAST_ROOT]"
	fi;
fi
WD_ROOT=$COAST_ROOT
# shellcheck disable=SC2034
KEEP_SCRIPT=${SCRIPTDIR:-.}/keepwds.sh;
# shellcheck disable=SC2034
START_SCRIPT=${SCRIPTDIR:-.}/startwds.sh;
# shellcheck disable=SC2034
STOP_SCRIPT=${SCRIPTDIR:-.}/stopwds.sh;
# shellcheck disable=SC2034
KEEPPIDFILE=${LOGDIRABS:-.}/.$SERVERNAME.keepwds.pid
# shellcheck disable=SC2034
RUNUSERFILE=${LOGDIRABS:-.}/.RunUser

versionFileAny=${CONFIGDIRABS:-.}/Version.any
versionFile=${CONFIGDIRABS:-.}/VERSION
PROJECTVERSION=""
if [ -f "$versionFileAny" ]; then
	# shellcheck disable=SC2034
	VERSIONFILE=$versionFileAny;
	# shellcheck disable=SC2034
	PROJECTVERSION="$(sed -n 's/^.*Release[ \t]*//p' "$versionFileAny" | tr -d '\"\t ').$(sed -n 's/^.*Build[ \t]*//p' "$versionFileAny" | tr -d '\"\t ')"
elif [ -f "$versionFile" ]; then
	# shellcheck disable=SC2034
	VERSIONFILE=$versionFile;
	# shellcheck disable=SC2034
	PROJECTVERSION="$(cat "$versionFile")"
fi
# shellcheck disable=SC2034
test -n "COAST_DOLOG" && WD_DOLOG=${COAST_DOLOG}
# shellcheck disable=SC2034
test -n "COAST_LOGONCERR" && WD_LOGONCERR=${COAST_LOGONCERR}

variablesToExport="BINDIR BINDIRABS CONFIGDIR CONFIGDIRABS LOGDIR LOGDIRABS PERFTESTDIR PRJCONFIGPATH PROJECTDIR PROJECTDIRABS PROJECTDIRNT PROJECTNAME PROJECTSRCDIR SCRIPTDIR SCRIPTDIRABS"
variablesToExport="$variablesToExport HOSTNAME DOMAIN PRJ_DESCRIPTION SERVERNAME"
variablesToExport="$variablesToExport INSTALLFILES PROJECTVERSION VERSIONFILE KEEP_SCRIPT START_SCRIPT STOP_SCRIPT KEEPPIDFILE RUNUSERFILE PID_FILE"
variablesToExport="$variablesToExport COAST_LIBDIR COAST_ROOT COAST_PATH"
variablesToExport="$variablesToExport COAST_DOLOG COAST_LOGONCERR COAST_LOGONCERR_WITH_TIMESTAMP COAST_USE_MMAP_STREAMS COAST_TRACE_INITFINIS COAST_TRACE_STATICALLOC COAST_TRACE_STORAGE"

# shellcheck disable=SC2086
export ${variablesToExport?}

# for debugging only
if [ $PRINT_DBG -ge 1 ]; then
	variablesToPrint="$sysfuncsExportvars $variablesToExport ServerMsgLog ServerErrLog PATH LD_LIBRARY_PATH RUN_ATTACHED_TO_GDB RUN_USER RUN_SERVICE RUN_SERVICE_CFGFILE APP_NAME WDA_BIN WDA_BINABS WDS_BIN WDS_BINABS"
	variablesToPrint="$(echo "$variablesToPrint" | tr ' ' '\n' | sort | uniq | tr '\n' ' ')"
	for varname in $variablesToPrint; do
		printEnvVar "${varname}";
	done
fi
