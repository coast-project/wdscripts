#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# generic script to start and stop Coast servers/apps either from an rc.x directory or locally
#
# init-usage:
#  you *must* create a symbolic link from the installed packages bootScript.sh location into the
#  the correct rc.x directory using appropriate start/kill script name
#
# example:
# - package installed at /export/apps/helloworld
#    the scripts for this app reside in /export/apps/helloworld/scripts
# - we want to start the server from within runlevel 2
#    $> cd /etc/rc2.d
#    $> ln -s /export/apps/helloworld/scripts/bootScript.sh S20helloworld
#    $> cd /etc/rc0.d
#    $> ln -s /export/apps/helloworld/scripts/bootScript.sh K20helloworld
#

if [ "$1" = "-D" ]; then
	PRINT_DBG=1
	cfg_dbgopt="-D";
	shift 1
else
	cfg_dbgopt="";
fi
PRINT_DBG=${PRINT_DBG:=0}
export PRINT_DBG

# unset all functions to remove potential definitions
# generated using $> cat bootScript.sh | sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p'
unset -f minimal_deref_link
unset -f printServerStatus
unset -f echoExit
unset -f exitWithStatus

# dereference a file - usually a link - and find its real origin as absolute path
#
# param $1 is the file/path to dereference
#
# output echo dereferenced file/path
# returning 0 in case the given name was linked, 1 otherwise
minimal_deref_link()
{
	mdfFilename=${1};
	mdfIsLink=1;
	if [ -h "$mdfFilename" ]; then
		mdfFilename=`ls -l $mdfFilename | sed -e 's|^[^>]*> ||' -e 's|/$||'`;
		mdfIsLink=0;
	fi
	echo "$mdfFilename";
	return $mdfIsLink;
}

callCmd="${0}";
derefd_name="`minimal_deref_link \"${callCmd}\"`"
bootScriptIsALinkReturn=$?
if [ $bootScriptIsALinkReturn -eq 0 ]; then
	link_name=${callCmd};
fi
bootScriptPath=`dirname $derefd_name`;
derefd_name=`basename $derefd_name`;
bootScriptName=${derefd_name};

. $bootScriptPath/sysfuncs.sh

my_uid=`getUid`
# getting the projectpath and -name is not simple because we have at least three ways
#  to get executed:
#  1. relative, or path expanded by shell using PATH variable
#  2. through a link to the real script
#  3. absolute path; use with caution as disambiguities might occur
#
# In case the scripts fullname is an absolute path, we implicitly assume that a 'cd ..' leads to the correct project directory.
#
prj_path=`PATH=/usr/bin:/bin:$PATH; pwd`
callCmdIsRelativeToProjectDir=0;
isAbsPath "${callCmd}" && isAbsPath "`relpath \"${callCmd}\" \"${prj_path}\"`" || callCmdIsRelativeToProjectDir=1;
prj_name=`basename $prj_path`
if [ $bootScriptIsALinkReturn -eq 0 ]; then
	prj_path=`dirname $bootScriptPath`;
	bootScriptPath=`cd ${bootScriptPath} && pwd`;
	cd $prj_path;
	prj_path=`pwd`;
	prj_name=`basename ${prj_path}`;
elif [ $callCmdIsRelativeToProjectDir -eq 1 ]; then
	prj_path=`dirname \`dirname ${callCmd}\``;
	cd $prj_path;
	prj_path=`pwd`;
	prj_name=`basename ${prj_path}`;
fi
isAbsPath "${prj_path}" || prj_pathabs=`makeAbsPath "$prj_path"`;

# Ensure being on th ecorrect project path by checking for an existing config* directory.
tmp_CfgDir="`SearchJoinedDir \"$prj_path\" \"$prj_name\" \"config\"`"
if [ -z "${tmp_CfgDir}" ]; then
	echo "ERROR: Unable to locate required *config* directory within potential project path [$prj_path], aborting!"
	exit 11
fi;

# load global config
. $bootScriptPath/config.sh
MYNAME=$bootScriptName	# used within trapsignalfuncs/serverfuncs for logging
. $bootScriptPath/serverfuncs.sh

# param 1: status entry in csv format
# param 2: status separator, default ':'
# param 3: message to print
printServerStatus()
{
	pssStatus="${1}";
	pssSep="${2:-:}";
	pssMessage="${3}";
	pssServerPid="`getCSVValue \"${pssStatus}\" ${serverAndKeepStatusServerPIDColumnId} \"${pssSep}\"`";
	pssKeepPid="`getCSVValue \"${pssStatus}\" ${serverAndKeepStatusKeepPIDColumnId} \"${pssSep}\"`";
	# check if keepwds.sh script is still in process list and
	#  the main pid of the wdserver is still present too
	pssAppendMessage=" (keep-pid:${pssKeepPid:-?}) (server-pid:${pssServerPid:-?})";
	pssTailText=$rc_done;
	if [ -n "${pssServerPid}" ]; then
		pssTailText=$rc_running;
	elif [ -z "${pssServerPid}" -a -z "${pssKeepPid}" ]; then
		if [ -f "${KEEPPIDFILE}" -o -f "${PID_FILE}"  ]; then
			pssTailText=$rc_dead
		else
			pssTailText=$rc_notExist;
		fi
	else
		pssTailText=$rc_notPossible;
	fi
	printf "%s" "${pssAppendMessage}"
	logMessageToFile "${pssMessage}${pssAppendMessage}" "${pssTailText}"
	echo "${pssTailText}";
}

# param 1: message to print
# param 2: return code
echoExit()
{
	echo "$1"
	exit $2
}

# param 1: message to print
# param 2: status entry, default is executing getServerAndKeepStatus
# param 3: exit code, default $serverRunning
exitWithStatus()
{
	ewsMessage="${1}";
	ewsStatusEntry="${2:-`getServerAndKeepStatus ${RUN_USER:-$my_uid}`}"
	ewsExitCode=${3:-$serverRunning};
	ewsStatusToAppend="`printServerStatus \"${ewsStatusEntry}\" \":\" \"${ewsMessage}\"`"
	echoExit "${ewsStatusToAppend}" $ewsExitCode
}

########## Start of program ##########
cfg_waitcount=1200;

if [ $PRINT_DBG -ge 1 ]; then
	echo ""
	for varname in link_name bootScriptName my_uid; do
		locVar="echo $"$varname;
		locVarVal=`eval $locVar`;
		printf "%-16s: [%s]\n" $varname "$locVarVal"
	done
	echo ""
fi

rc_done="..done"
rc_running="..running"
rc_failed="..failed"
rc_dead="..dead"
rc_notExist="..not running"
rc_notPossible="..invalid constellation, either keepwds or server can not be detected"

serverRunning=0             # server is running and everything seems to be ok
serverNotRunning=1          # server isn't running
serverNotRunningButKeepIs=2 # server isn't running, but keepwds seems to be, might indicate a looping/restarting server
serverRunningButNoKeep=4    # server is running but keepwds is not

statusToAppend=$rc_done

Command="$1";
test $# -ge 1 && shift 1
cfg_srvopts="$@";

CommandText="";

case "$Command" in
	start)
		CommandText="Starting";
	;;
	stop)
		CommandText="Stopping";
	;;
	status)
		CommandText="Status of";
	;;
	restart)
		CommandText="Restarting";
	;;
	reload)
		CommandText="Reloading";
	;;
	*)
		CommandText="No command given";
	;;
esac

serverString="$SERVERNAME server";
outmsg="${CommandText} ${serverString}";

printf "%s" "${outmsg}";
exitIfDisabledService "${outmsg}"

case "$Command" in
	start)
		myStatusEntry="`getServerAndKeepStatus ${RUN_USER:-$my_uid}`"
		# test if server is still running
		if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" ]; then
			printf "INFO: %s already running, no need to start again.\n" "$SERVERNAME" >&2
			exitWithStatus "${outmsg}" "${myStatusEntry}" $serverRunning
		fi
		removeFiles ${KEEPPIDFILE} ${PID_FILE} ${RUNUSERFILE};
		if [ $my_uid -eq 0 -a -n "${RUN_USER}" ]; then
			outmsg="${outmsg} as ${RUN_USER}";
		fi
		pidOfKeep=`startWithKeep "${RUN_USER}" "${KEEP_SCRIPT}" "${RUNUSERFILE}" "${KEEPPIDFILE}" ${cfg_srvopts}`;
		waitForStartedServer "${RUN_USER}" 20
		exitWithStatus "${outmsg}"
	;;
	stop)
		myStatusEntry="`getServerAndKeepStatus ${RUN_USER:-$my_uid}`";
		myKeepPid="`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusKeepPIDColumnId} \":\"`";
		# test if server is still running
		if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusKeepStatusColumnId} \":\"`" = "0" -a -n "${myKeepPid}" ]; then
			# we need to kill the keepwds.sh script to terminate the server and not restart it again
			# it can take up to ten seconds until the script checks the signal and terminates the server
			killedKeepPid=""
			SignalToServer 15 "TERM" "${myKeepPid}" "killedKeepPid" "${KEEP_SCRIPT}" 2>/dev/null
			myServerPid="`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusServerPIDColumnId} \":\"`";
			WaitOnTermination ${cfg_waitcount} ${myKeepPid} ${myServerPid}
			if [ $? -ne 0 ]; then
				exitWithStatus "${outmsg} still in progress"
			fi
		else
			# server potentially running but keepwds is not
			if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" ]; then
				sendSignalToServerAndWait 15 "TERM" "`determineRunUser`" ${cfg_waitcount} 2>/dev/null
				if [ $? -ne 0 ]; then
					# try hardkill to ensure it died
					sendSignalToServerAndWait 9 "KILL" "`determineRunUser`" ${cfg_waitcount} 2>/dev/null
				fi;
			else
				# no server and no keepwds
				statusToAppend=$rc_notExist;
			fi;
			exitWithStatus "${outmsg}"
		fi;
		removeFiles ${KEEPPIDFILE} ${PID_FILE} ${RUNUSERFILE}
	;;
	status)
		exitWithStatus "${outmsg}"
	;;
	restart)
		myStatusEntry="`getServerAndKeepStatus ${RUN_USER:-$my_uid}`";
		# test if server is still running
		if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" ]; then
			# server is still running, if we kill using stop script
			# the keepwds.sh script will automatically restart the server when it was down
			sendSignalToServerAndWait 15 "TERM" "`determineRunUser`" ${cfg_waitcount}
			if [ $? -ne 0 ]; then
				# try hardkill to ensure it died
				sendSignalToServerAndWait 9 "KILL" "`determineRunUser`" ${cfg_waitcount}
			fi;
		fi;
		myStatusEntry="`getServerAndKeepStatus ${RUN_USER:-$my_uid}`";
		if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusKeepStatusColumnId} \":\"`" = "1" ]; then
			# keepwds.sh was not present, start server again using keepwds.sh
			pidOfKeep=`startWithKeep "${RUN_USER}" "${KEEP_SCRIPT}" "${RUNUSERFILE}" "${KEEPPIDFILE}" ${cfg_srvopts}`;
			test $pidOfKeep -eq 0 && statusToAppend=$rc_failed;
		fi;
		waitForStartedServer "${RUN_USER}" 30
		exitWithStatus "${outmsg}"
	;;
	reload)
		myStatusEntry="`getServerAndKeepStatus ${RUN_USER:-$my_uid}`";
		# test if server is still running
		if [ "`getCSVValue \"${myStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" ]; then
			sendSignalToServerAndWait 1 "HUP" "`determineRunUser`" 0
			exitWithStatus "${outmsg}"
		else
			# no server and no keepwds
			statusToAppend=$rc_notPossible;
		fi;
	;;
	*)
		outmsg="${CommandText}: ${bootScriptName} {start|stop|status|restart|reload} [(re-)start arguments...], given [$@]";
		echo $outmsg;
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${bootScriptName}" "${outmsg}" >> ${ServerMsgLog}
		exit 1
	;;
esac

echo "$statusToAppend"
exit 0
