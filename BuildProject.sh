#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# builds the current project using SNiFF settings
#
############################################################################

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -b : batch mode, no sleeps for messages'
	echo ' -l : do not use internal lock-file mechanism'
	echo ' -m : make the given target(s), default is "clean_targets all"'
	echo ' -n : do not update the makefiles using SNiFF'
	echo ' -w <we_pattern> : available WorkingEnvironments are matched against this pattern to'
	echo '                   automatically select a WorkingEnvironment for compilation'
	echo '                   if we_pattern is the empty string ("") the first WE will be taken'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_batch=0;
cfg_nolock=0;
cfg_noupdate=0;
cfg_weset=0;
cfg_makeopt="clean_targets all";
# process command line options
while getopts ":blm:nw:D" opt; do
	case $opt in
		b)
			# set variable telling we are in batch mode, disabling sleep calls
			cfg_batch=1;
		;;
		l)
			# do not use internal lock-file
			cfg_nolock=1;
		;;
		m)
			# only do the given make targets
			cfg_makeopt="${OPTARG}";
			echo 'make targets are ['$cfg_makeopt']'
		;;
		n)
			# do not update makefiles
			cfg_noupdate=1;
		;;
		w)
			# specify pattern to automatically match a working environment for compilation
			cfg_wepattern="${OPTARG}"
			cfg_weset=1;
			echo 'pattern for we is ['${cfg_wepattern}']'
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

DNAM=`dirname $0`
if [ "${DNAM}" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

# load configuration for current project
. ${mypath}/config.sh $cfg_opt

if [ -z "${SNIFF_DIR}" ]; then
	echo 'ERROR: variable SNIFF_DIR not set!'
	exit 4;
fi

# for SNiFF helper functions
. ${mypath}/SniffUtils.sh

# try to locate the project
SNIFFPROJNAME=`cd ${PROJECTDIR} && find . -name "${PROJECTNAME}.shared" -type f ${FINDOPT}`

if [ -z "${SNIFFPROJNAME}" ]; then
	echo Looking for ${PROJECTNAME}.shared not successful:
	echo trying to find SNiFF project "("'*.shared'")" in $PROJECTDIR
	SNIFFPROJNAME=`cd ${PROJECTDIR} && find . -name "*.shared" -type f ${FINDOPT}`
fi
SNIFFPROJNAME=${SNIFFPROJNAME##*/}

if [ -z "${SNIFFPROJNAME}" ]; then
	echo 'giving up to find SNiFF project'
	exit 4
fi

if [ $cfg_nolock -eq 0 ]; then
	LOCK_FILE=$PROJECTDIR/Build.lock
fi

SNIFF_SESSION_ID=`echo "${USER}_${PROJECTNAME}" | cut -c-15`
if [ "${USER}_${PROJECTNAME}" != "$SNIFF_SESSION_ID" ]; then
	echo 'WARNING: SNIFF_SESSION_ID has been cut to ['$SNIFF_SESSION_ID']';
fi

if [ ${PRINT_DBG} -eq 1 ]; then
	echo ""
	echo "SNIFF_DIR: ["${SNIFF_DIR}"]"
	echo "SNIFFPROJNAME: ["${SNIFFPROJNAME}"]"
	echo "LOCK_FILE: ["${LOCK_FILE}"]"
	echo "SNIFF_SESSION_ID: ["${SNIFF_SESSION_ID}"]"
	echo "I am: ["${USER}"]"
fi

if [ $cfg_nolock -eq 0 ]; then
	if [ -e $LOCK_FILE ] ; then
		# if the lock file is present someone is already running a build
		echo "Build is already at work or stuck"
		echo "Please remove the $LOCK_FILE manually if the build is not running anymore"
		echo " and start over again"
		exit 4
	fi
fi

function cleanfiles
{
	if [ $cfg_nolock -eq 0 ]; then
		rm -f $LOCK_FILE;
	fi
}

function build_exitproc
{
	cleanfiles;
	SniffQuit "${SNIFF_SESSION_ID}";
	exit 4;
}

trap build_exitproc INT
trap build_exitproc HUP
trap build_exitproc TERM
trap build_exitproc KILL

if [ $cfg_nolock -eq 0 ]; then
	touch $LOCK_FILE
fi

if [ $cfg_batch -eq 0 ]; then
cat << EOF


============== Building project [$SNIFFPROJNAME] in [$PROJECTDIR] with make options [$cfg_makeopt] ==============

Please make sure the project is not already
opened in a graphical interactive SNiFF Session. SNiFF needs
exclusive access to the project while executing commands.

EOF
	sleep 3
fi

cd ${PROJECTDIR}

if [ $isWindows -eq 1 ]; then
	myPROJPATH=${PROJECTDIRNT}
	myPROJPATHABS=${PROJECTDIRNT}
else
	myPROJPATH=${PROJECTDIR}
	myPROJPATHABS=${PROJECTDIRABS}
fi

SniffGetWorkingEnvsForUser "${USER}" "${myPROJPATH}" "${myPROJPATHABS}" "SNIFF_WORKINGENVS"

if [ $cfg_weset -eq 0 ]; then
	# interactive mode
	echo
	echo Select the PrivateWorkingEnvironment in which you want to compile "("PWE-Name:RootOfWE")"
	echo
	select wename in ${SNIFF_WORKINGENVS} eXit; do
		if [ "${wename}" = "eXit" ]; then
			build_exitproc;
		fi
		SNIFFWE=${wename%%\&*}
		SNIFFWEROOT=${wename##*\&}
		SNIFFPLATFORMNAME=${wename%\&*}
		SNIFFPLATFORMNAME=${SNIFFPLATFORMNAME#*\&}
		if [ "${SNIFFWEROOT}" = "\$DEV_HOME" ]; then
			SNIFFWEROOT=${DEV_HOME}
		fi;
		break;
	done
else
	tmpwe="";
	for wename in ${SNIFF_WORKINGENVS}; do
		if [ -z "${cfg_wepattern}" ]; then
			# empty pattern selects first WE by default
			tmpwe=${wename};
			break;
		fi
		# check for pattern match
		grepret=`echo $wename | grep -c "${cfg_wepattern}"`
		if [ $grepret -ne 0 ]; then
			tmpwe=${wename};
			break;
		fi
	done
	if [ -n "${tmpwe}" ]; then
		SNIFFWE=${tmpwe%%\&*}
		SNIFFWEROOT=${tmpwe##*\&}
		SNIFFPLATFORMNAME=${tmpwe%\&*}
		SNIFFPLATFORMNAME=${SNIFFPLATFORMNAME#*\&}
		if [ "${SNIFFWEROOT}" = "\$DEV_HOME" ]; then
			SNIFFWEROOT=${DEV_HOME}
		fi;
	fi;
fi

if [ -z "${SNIFFWE}" ]; then
	echo "Can not continue without valid WorkingEnvironment!"
	build_exitproc
fi
if [ "${SNIFFPLATFORMNAME}" = "<default>" ]; then
	echo 'Can not continue without valid Platform, ['${SNIFFPLATFORMNAME}'] can not be used here!'
	build_exitproc
fi

echo
echo using PWE:${SNIFFWE} in ${SNIFFWEROOT} with Platformfile ${SNIFFPLATFORMNAME}
echo

if [ $cfg_noupdate -eq 0 ]; then
	# before we start SNIFF in the first place we remove the project cache
	# of this WorkingEnvironment (Sniff may get confused on certain changes
	# otherwise)
	rm -f ${SNIFF_DIR}/workingenvs/WEProjectCache/${USER}_PWE#${SNIFFWE}
	# need to change hyphen to underscore for directoryname
	# but only for the following...?!
	tmpWEName=`echo ${SNIFFWE} | sed "s/-/_/g"`
	rm -rf ${SNIFF_DIR}/workingenvs/.snifflock/${USER}_PWE_$tmpWEName
	rm -rf ${SNIFFWEROOT}/.sniffdb
	rm -rf ${SNIFFWEROOT}/.ProjectCache

	#StartSniff because it needs some time to start up
	SniffStart "${SNIFF_SESSION_ID}"
fi

SniffGetPlatformMakefileNameAndMakeCommand "${SNIFFPLATFORMNAME}" "SNIFF_PLATFORM" "SNIFF_MAKECMD"
if [ ${PRINT_DBG} -eq 1 ]; then
	echo "SNIFF_MAKECMD: ["${SNIFF_MAKECMD}"]"
	echo "SNIFF_PLATFORM: ["${SNIFF_PLATFORM}"]"
fi
export PLATFORM=${SNIFF_PLATFORM}

if [ -z "${SNIFF_MAKECMD}" ]; then
	echo "Can not continue without valid MakeCommand from SNiFF-Platform file!"
	build_exitproc
fi

if [ $cfg_noupdate -eq 0 ]; then
	# only update makefiles when needed
	SniffCheckRunning "${SNIFF_SESSION_ID}" "${USER}"
	retcode=$?
	if [ $retcode -eq 0 ]; then
		echo "### SNiFF could not be started within 40s ###"
		build_exitproc
		# ? maybe quit sniff here and start it over again ?
	fi

	# cut the root part of the directory to get the part relative to WE_ROOT of SNiFF
	RELSNIFFPROJ=${myPROJPATH#${SNIFFWEROOT}/}
	if [ ${PRINT_DBG} -eq 1 ]; then
		echo "RELSNIFFPROJ: ["${RELSNIFFPROJ}"]"
	fi

	SniffOpenProject "${SNIFF_SESSION_ID}" "${RELSNIFFPROJ}" "${SNIFFPROJNAME}" "PWE:${SNIFFWE}"
	SniffUpdateMakefiles "${SNIFF_SESSION_ID}" "${SNIFFPROJNAME}"
	SniffCloseProject "${SNIFF_SESSION_ID}" "${SNIFFPROJNAME}"

	SniffQuit "${SNIFF_SESSION_ID}"
fi

echo "============== making targets ["$cfg_makeopt"] for ["${SNIFFPROJNAME}"]"
${SNIFF_MAKECMD} $cfg_makeopt

cleanfiles;

exit 0
