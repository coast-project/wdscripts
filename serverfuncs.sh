#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2006, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# specific functions for server signal sending, killing and termination waiting
#

# unset all functions to remove potential definitions
# generated using $> sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p' serverfuncs.sh | grep -v "\$$"
unset -f LogScriptMessage
unset -f LogEnterScript
unset -f LogLeaveScript
unset -f findProcPathAndWorkingDirs
unset -f checkProcessWithName
unset -f WaitOnTermination
unset -f SignalToServer
unset -f logMessageToFile
unset -f removeOrphanedPidFile
unset -f exitIfDisabledService
unset -f getServerStatus
unset -f getKeepwdsStatus
unset -f quoteargs
unset -f startWithKeep
unset -f getServerAndKeepStatus
unset -f waitForStartedServer
unset -f sendSignalToServerAndWait
unset -f determineRunUser

# this script should be sourced only and requires sysfuncs to be loaded
[ "$(basename "$0")" = "serverfuncs.sh" ] && { echo "This script, $(basename "$0"), should be sourced only, aborting!"; exit 2; }
[ "${SYSFUNCSLOADED:-0}" -eq 1 ] || { echo "This script, $(basename "$0"), requires sysfuncs.sh to be loaded first, aborting!"; exit 2; }

# log into server.msg and server.err some message
# param 1: message
#
LogScriptMessage()
{
	# shellcheck disable=SC2154
	printf "%s %s: %s\n" "$(date +%Y%m%d%H%M%S)" "${MYNAME}" "${1}" | tee -a "${ServerMsgLog}" "${ServerErrLog}";
}

# log into server.msg and server.err that we are entering the script
#
LogEnterScript()
{
	LogScriptMessage "---- entering ----";
}

# log into server.msg and server.err that we are leaving the script
#
# param 1: exit code to log
#
LogLeaveScript()
{
	LogScriptMessage "---- leaving (${1}) ----";
}

# get a separated list of proc-directory:working-directory tuples
#
# param 1: name of user the process is running as
#          default current user, use 0 (root) to test for all processes if your privileges allow
# param 2: separator, default ':'
findProcPathAndWorkingDirs()
{
	__trace_on
	procUid="${1:-0}";
	procSep="${2:-:}";
	_startpath="${3:-/proc}";
	[ "${procUid:-0}" = "0" ] && procUid= || procUid="-user $(getUid "$procUid")";
	# shellcheck disable=SC2156,SC2086
	find -H "$_startpath" \( ! -path "${_startpath}/*/*" -o -prune \) $procUid -type l -path '*/cwd' -exec sh -c "$(myWhich ls) -n {} | sed -e 's/.*[0-9]*:[0-9]* //' -e \"s/ -> /$procSep/\"" \; 2>/dev/null
	__trace_off
}

# check for a match for the given user and process name in the process list
#
# param 1: path/name of process to lookup in process list
# param 2: arguments to the process if any
# param 3: name of user the process is running as
#          default current user, use 0 (root) to test for all processes if your privileges allow
# param 4: path in which the server was started, in case we are not able to find process arguments
# param 5: set to 1 if process argument match is required,
#          degrades automatically if we are looking for a script, default 0
#
# output the first matching pid
# return 0 in case such a process exists, 1 otherwise
checkProcessWithName()
{
	__trace_on
	cpwnBinName="${1}";
	cpwnProcessArguments="${2}";
	cpwnRunUser="${3}";
	cpwnProjectDir="${4}";
	cpwnArgumentMatchMandatory=${5:-0};
	cpwnSuccess=0;
	cpwnFailure=1;
	cpwnReturnCode=${cpwnFailure};
	_col_proc_dir=1
	_col_work_dir=2
	cpwnDirCandidates="$(findProcPathAndWorkingDirs "$cpwnRunUser" ":")";
	cpwnLsBinary=$(myWhich ls);
	for processBaseDir in ${cpwnDirCandidates}; do
		proc_dir="$(dirname "$(getCSVValue "$processBaseDir" "$_col_proc_dir")")";
		cpwnProcessCWD="$(getCSVValue "$processBaseDir" "$_col_work_dir")"
		# check if the project directory matches the servers working directory
		test "${cpwnProcessCWD}" = "${cpwnProjectDir}" || continue;
		cpwnProcessPath="";
		cpwnCmdArgsMatched=0;
		# find executable path
		for exeCand in $proc_dir/a.out $proc_dir/exe; do
			test -L "${exeCand}" || continue;
			# get link to binary
			cpwnProcessPath=$(${cpwnLsBinary} -l "$exeCand" 2>/dev/null| cut -d'>' -f2- | cut -d' ' -f2-);
			# sanity check if a link to the binary is available
			test -n "${cpwnProcessPath}" || continue;

			cpwnProcessPath="$(echo "$cpwnProcessPath" | sed -n "\|.*${cpwnBinName}.*|p")";
			# check if binary matched, if it was only the surrounding shell we bail out
			test -n "${cpwnProcessPath}" || continue;
			# also check if parts of the command line match, shortcut if empty
			test -z "${cpwnProcessArguments}" && break;

			# depending on target system only one item of the list is defined
			for cpwnCmdLineTry in "$proc_dir"/psinfo "$proc_dir"/cmdline; do
				test -r "${cpwnCmdLineTry}" || continue;
				# only use the last part (basename) of the command, command line has \0 separators and might contain control characters
				_grepBin=$(myWhich grep)
				cpwnCmdArgsMatched=$(tr '\0' ' ' < "${cpwnCmdLineTry}" | tr -d '[:cntrl:]' | "$_grepBin" -c "$(basename "${cpwnBinName}") ${cpwnProcessArguments}");
				# test if the command argument matched
				# shellcheck disable=SC2086
				[ ${cpwnCmdArgsMatched:-0} -eq 0 ] && continue;
			done
			# shellcheck disable=SC2086
			[ ${cpwnCmdArgsMatched:-0} -gt 0 ] && break;
		done
		if [ -z "${cpwnProcessPath}" ]; then
			# probably a script we are looking for, check the fd's
			# in case a script was started from within a shell instance
			#  we need to check for fd entries to find the real executable
			# linux: fd entries link to files directly, mode can not be used to distinguish between files and special devices
			# solaris: fd entries are used to lookup within /proc/*/path/, mode (not link and executable) can be used
			for fdCand in "${proc_dir}"/fd/*; do
				test ! -h "${fdCand}" && test -x "${fdCand}" && fdCand="${proc_dir}/$(basename "${fdCand}")";
				cpwnProcessPath=$(${cpwnLsBinary} -l "$fdCand" 2>/dev/null| cut -d'>' -f2- | cut -d' ' -f2-);
				cpwnProcessPath="$(echo "$cpwnProcessPath" | sed -n "\|.*${cpwnBinName}.*|p")";
				# check if script matched
				test -n "${cpwnProcessPath}" || continue;
				# disable argument matching as we can not do it with scripts running inside a shell
				#  as the script is the first argument to the shell already
				cpwnArgumentMatchMandatory=0;
				break;
			done
		fi
		# do it again if no matching executable found so far
		test -n "${cpwnProcessPath}" || continue;
		# almost done, is an argument match mandatory or not?
		# shellcheck disable=SC2086
		if [ "${cpwnArgumentMatchMandatory:-0}" -eq 0 ] || [ ${cpwnCmdArgsMatched:-0} -gt 0 ]; then
			# basename of proc dir is the pid we are interested in
			basename "$proc_dir";
			return $cpwnSuccess;
		fi
	done; # processBaseDir
	__trace_off
	return $cpwnReturnCode;
}

# wait on termination of given process ids
#
# param 1: max time to wait on termination in seconds
# param 2.. list of process ids
#
# requires the following variables to be set: MYNAME, SERVERNAME, HOSTNAME, ServerMsgLog
#
# return:
#  0 in case the process stopped within the time given
#  1 if the process was still alive after the time given
#
WaitOnTermination()
{
	wotWaitCount=${1};
	test $# -ge 2 || return 1;
	shift 1
	wotPids="$*";
	wotOrgPids="$*";
	wotHasStopped=0;
	wotReturnCode=1;
	wotNewPids="";
	if [ "${PRINT_DBG:-0}" -ge 2 ]; then echo "wotPids [${wotPids}]"; fi;
	wotWaitCount=$((wotWaitCount / 2));
	while [ $wotWaitCount -ge 0 ]; do
		wotWaitCount=$((wotWaitCount - 1));
		wotNewPids="";
		for curPid in $wotPids; do
			if [ "${PRINT_DBG:-0}" -ge 2 ]; then echo "curPid [${curPid}]"; fi;
			checkProcessId "${curPid}"
			if [ $? -eq 1 ]; then
				wotHasStopped=$((wotHasStopped + 1));
			else
				if [ -n "${wotNewPids}" ]; then wotNewPids="${wotNewPids} ";fi;
				wotNewPids="${wotNewPids}${curPid}";
			fi
		done;
		if [ -n "${wotNewPids}" ]; then
			wotPids="${wotNewPids}";
			if [ "${PRINT_DBG:-0}" -ge 2 ]; then echo "new wotPids [${wotPids}]"; fi;
		else
			break;
		fi
		printf "."
		sleep 2
	done
	printf "%s %s: " "$(date +%Y%m%d%H%M%S)" "${MYNAME}" >> "${ServerMsgLog}";
	# shellcheck disable=SC2039
	printf "server %s on %s with pid(s) %s..." "${SERVERNAME}" "${HOSTNAME}" "${wotOrgPids}" >> "${ServerMsgLog}";
	if [ ${wotHasStopped} -ge 1 ]; then
		printf "stopped\n" >> "${ServerMsgLog}";
		wotReturnCode=0;
	else
		printf "still running!\n" >> "${ServerMsgLog}";
	fi
	return $wotReturnCode;
}

# send signal to list of PIDs
#
# param $1 signal number to send
# param $2 name of signal to send, for logging purposes only
# param $3 list of PID(s) to send signal to
# param $4 name of variable to put signalled pids into, must be defined and initialized in outer scope
# param $5 name of process to send signal to
#
# return:
#  0 in case the signal could be successfully sent to the process
#  1 if the process with the given pid did not exist anymore
#  2 signalling failed due to some reason (permission etc.)
#
SignalToServer()
{
	stsSigNum=${1};
	stsSigName=${2};
	stsPids="${3}";
	stsExpVar="${4}";
	stsBinName="${5:-?}";
	stsPidKilled="";
	stsReturnCode=0;
	kErrMsg="";
	stsDoFirst=1;
	if [ -n "${stsPids}" ]; then
		for stsPidToReturn in ${stsPids}; do
			checkProcessId "${stsPidToReturn}" && {
				if [ $stsDoFirst -eq 1 ]; then
					printf "%s %s: " "$(date +%Y%m%d%H%M%S)" "${MYNAME}" | tee -a "${ServerMsgLog}" "${ServerErrLog}" >&2
					printf "sending SIG%s (%s) to process (%s)" "${stsSigName}" "${stsSigNum}" "${stsBinName}" | tee -a "${ServerMsgLog}" "${ServerErrLog}" >&2
					stsDoFirst=0;
				fi
				[ -n "${kErrMsg}" ] && kErrMsg="${kErrMsg} ";
				kErrMsg="$kErrMsg"$(kill -"${stsSigNum}" "${stsPidToReturn}");
				killReturnCode=$?
				printf ", %s" "${stsPidToReturn}" | tee -a "${ServerMsgLog}" "${ServerErrLog}" >&2
				if [ $killReturnCode -eq 0 ]; then
					if [ -n "${stsPidKilled}" ]; then stsPidKilled="${stsPidKilled} "; fi
					stsPidKilled="${stsPidKilled}${stsPidToReturn}";
				else
					printf "(failed pid:%s)" "${stsPidToReturn}" | tee -a "${ServerMsgLog}" "${ServerErrLog}" >&2
					stsReturnCode=2;
				fi
			}
		done
		if [ -n "${kErrMsg}" ]; then
			printf "\n Error(s) [%s]" "${kErrMsg}" | tee -a "${ServerMsgLog}";
		fi
		if [ $stsDoFirst -eq 1 ]; then
			printf "%s %s: " "$(date +%Y%m%d%H%M%S)" "${MYNAME}" >> "${ServerMsgLog}";
			printf "process (%s) is not running anymore\n" "${stsBinName}" | tee -a "${ServerMsgLog}" >&2
			stsReturnCode=1;
		fi
	else
		printf "%s %s: " "$(date +%Y%m%d%H%M%S)" "${MYNAME}" >> "${ServerMsgLog}";
		printf "WARNING: no PID(s) given for process (%s)\n" "${stsBinName}" | tee -a "${ServerMsgLog}" >&2;
		stsReturnCode=1;
	fi
	eval "${stsExpVar}"="${stsPidKilled}";
	export "${stsExpVar?}"
	return $stsReturnCode;
}

# param 1: message
# param 2: status text to append
# param 3: logfilename, default ServerMsgLog
#
logMessageToFile()
{
	lmMessage="${1}";
	lmMessageTail="${2}";
	lmLogfileName="${3:-${ServerMsgLog}}";
	printf "%s %s: %s%s\n" "$(date +%Y%m%d%H%M%S)" "${MYNAME}" "${lmMessage}" "${lmMessageTail}" >> "${lmLogfileName}";
}

# param 1: pidfilename
# param 2: infotext
removeOrphanedPidFile()
{
	ropfFilename="${1}";
	test -n "${ropfFilename}" || return 0;
	test -f "${ropfFilename}" || return 0;
	logMessageToFile "${2}"
	rm -f "${ropfFilename}" 2>/dev/null;
}

# check if we have to execute anything depending on RUN_SERVICE setting
# -> this scripts execution will only be disabled when RUN_SERVICE is set to 0
#
# param 1: message to write out
# param 2: status to append to message
#
exitIfDisabledService()
{
	eidsMessage="${1}";
	eidsStatus="${2}";
	test -z "${eidsStatus}" && eidsStatus=" => will not execute, because it was disabled (RUN_SERVICE=0)!";
	if [ -n "${RUN_SERVICE}" ] && [ "${RUN_SERVICE:-1}" -eq 0 ]; then
		echo "${eidsStatus}"
		logMessageToFile "${eidsMessage}" "${eidsStatus}"
		exit 7;
	fi
}

# param 1: pidfilename
# param 2: wds_binabs
# param 3: wds_bin
# param 4: servername
# param 5: run user name
#
# required variables: PROJECTDIRABS
#
# output: echo the processes PID if any, return 0 in case the server is still running, 1 otherwise
getServerStatus()
{
	gssPidFile="${1}";
	gssWdsBinAbs="${2}";
	gssWdsBin="${3}";
	gssServername="${4}";
	gssRunUser="${5}";
	gssPid="$(getPIDFromFile "${gssPidFile}")";
	test -n "${gssPid}" && checkProcessId "${gssPid}" && echo "${gssPid}" && return 0;
	# information from file was useless, delete it
	test -f "${gssPidFile}" && removeOrphanedPidFile "${gssPidFile}" "INFO: orphaned server-pidfile found but server: ${gssServername} was not running anymore"
	# start search with maximum specification and the reduce
	for gssSearchInPS in "${gssWdsBinAbs}" "${gssWdsBin}"; do
		gssPid="$(checkProcessWithName "${gssSearchInPS}" "${gssServername}" "${gssRunUser}" "${PROJECTDIRABS}" 1)" || continue
		gssCheckStatus=$?;
		echo "${gssPid}";
		return ${gssCheckStatus};
	done
	return 1;
}

# param 1: pidfilename
# param 2: keep script name
# param 3: run user name
#
# required variables: PROJECTDIRABS
#
# output: echo the processes PID if any, return 0 in case the script is still running, 1 otherwise
getKeepwdsStatus()
{
	gksPidFile="${1}";
	gksScriptname="${2}";
	gksRunUser="${3}";
	gksPid="$(getPIDFromFile "${gksPidFile}")";
	test -n "${gksPid}" && checkProcessId "${gksPid}" && echo "${gksPid}" && return 0;
	# information from file was useless, delete it
	test -f "${gksPidFile}" && removeOrphanedPidFile "${gksPidFile}" "INFO: orphaned keepwds-pidfile found but keepwds.sh is not running anymore"
	gksPid="$(checkProcessWithName "${gksScriptname}" "" "${gksRunUser}" "${PROJECTDIRABS}" 0)"
	gksCheckStatus=$?;
	echo "${gksPid}";
	return ${gksCheckStatus};
}

# quoteargs
# param ...:
# returns arguments properly double quoted
quoteargs()
{
	for i in "$@"; do
	  _qa="$_qa \"$i\""
	done
	echo "${_qa:-}"
}

# param 1: name of user to start as
# param 2: path to keepwds.sh
# param 3: path to file in which to store run user
# param 4: path to file in which to store keepwds pid
# param 5..: arguments to pass to server
#
# required variables: ServerMsgLog, ServerErrLog
startWithKeep()
{
	swkPidOfKeepwds=0;
	swkRunUser=${1};
	swkKeepwdsFile=${2};
	swkRunUserFile=${3};
	swkKeepPidFile=${4};
	shift 4
	test "${PRINT_DBG:-0}" -ge 1 && swkScriptDebug="-D"
	swkAmIroot=0;
	test "$(getUid)" -eq 0 && swkAmIroot=1;
    swkServerArguments="$(quoteargs "$@")"
	if [ $swkAmIroot -eq 1 ] && [ -n "${swkRunUser}" ]; then
		# must adjust the owner of the probably newly created server-log-files
		if [ -n "${ServerMsgLog}" ] && [ -f "${ServerMsgLog}" ]; then chown "${swkRunUser}" "${ServerMsgLog}"; fi;
		if [ -n "${ServerErrLog}" ] && [ -f "${ServerErrLog}" ]; then chown "${swkRunUser}" "${ServerErrLog}"; fi;
		# write run-user into special file for later server destruction
		echo "${swkRunUser}" > "${swkRunUserFile}";
		chown "${swkRunUser}" "${swkRunUserFile}";
		su "${swkRunUser}" -c "${swkKeepwdsFile} ${swkScriptDebug} -- ${swkServerArguments} >/dev/null 2>&1 & echo \$! > ${swkKeepPidFile}";
	else
		# shellcheck disable=SC2086
		${swkKeepwdsFile} ${swkScriptDebug} -- ${swkServerArguments} >/dev/null 2>&1 &
		swkPidOfKeepwds=$!;
		echo $swkPidOfKeepwds > "${swkKeepPidFile}";
	fi;
	swkPidOfKeepwds="$(getPIDFromFile "${swkKeepPidFile}")";
	echo "${swkPidOfKeepwds}";
}

serverAndKeepStatusServerPIDColumnId=1;
serverAndKeepStatusServerStatusColumnId=2;
# shellcheck disable=SC2034
serverAndKeepStatusKeepPIDColumnId=3;
serverAndKeepStatusKeepStatusColumnId=4;

# param 1: user name to find running instances for
# param 2: separator, default ':'
# param 3: full path of process, default $WDS_BINABS
# param 4: name of process, default $WDS_BIN
#
# required variables: PID_FILE, WDS_BINABS, WDS_BIN, SERVERNAME, KEEPPIDFILE, KEEP_SCRIPT
#
getServerAndKeepStatus()
{
	gsaksRunUser="${1}";
	gsaksSep="${2:-:}";
	gsaksBinAbs="${3:-$WDS_BINABS}";
	gsaksBin="${4:-$WDS_BIN}";
	gsaksServerPid=$(getServerStatus "${PID_FILE}" "${gsaksBinAbs}" "${gsaksBin}" "${SERVERNAME}" "${gsaksRunUser}");
	gsaksServerStatus=$?
	gsaksKeepPid=$(getKeepwdsStatus "${KEEPPIDFILE}" "${KEEP_SCRIPT}" "${gsaksRunUser}");
	gsaksKeepStatus=$?
	echo "${gsaksServerPid}${gsaksSep}${gsaksServerStatus}${gsaksSep}${gsaksKeepPid}${gsaksSep}${gsaksKeepStatus}";
}

# param 1: user to run server as
# param 2: time to wait for startup, default 10s
# param 3: full path of process, default $WDS_BINABS
# param 4: name of process, default $WDS_BIN
#
# return 0 in case
waitForStartedServer()
{
	wfssRunUser="${1}";
	wfssWaitTime=${2:-10};
	wfssBinAbs="${3:-$WDS_BINABS}";
	wfssBin="${4:-$WDS_BIN}";
	wfssSleepTime=2;
	wfssStatusEntry="$(getServerAndKeepStatus "$wfssRunUser" ":" "$wfssBinAbs" "$wfssBin")"
	wfssWaitCount=$((wfssWaitTime / wfssSleepTime));
	while [ $wfssWaitCount -ge 0 ]; do
		wfssWaitCount=$((wfssWaitCount - 1));
		if [ "$(getCSVValue "${wfssStatusEntry}" ${serverAndKeepStatusServerStatusColumnId} ":")" = "0" ] && [ "$(getCSVValue "${wfssStatusEntry}" ${serverAndKeepStatusKeepStatusColumnId} ":")" = "0" ]; then
			return 0;
		fi
		printf "." >&2
		sleep $wfssSleepTime;
		wfssStatusEntry="$(getServerAndKeepStatus "$wfssRunUser" ":" "$wfssBinAbs" "$wfssBin")"
	done
	return 1
}

# param 1: numeric signal to send
# param 2: signal name
# param 3: user the server runs as
# param 4: time to wait on termination
# param 5: full path of process to kill, default $WDS_BINABS
# param 6: name of process to kill, default $WDS_BIN
#
# variables used: PID_FILE, RUNUSERFILE
#
# return 0 in case termination was successful
sendSignalToServerAndWait()
{
	kswsawSigToSend=${1:-15};
	kswsawSigToSendName="${2-TERM}";
	kswsawRunUser=${3};
	kswsawWaitCount=${4:-60};
	kswsawBinAbs="${5:-$WDS_BINABS}";
	kswsawBin="${6:-$WDS_BIN}";
	kswsawKilledPid="";
	kswsawStatusEntry="$(getServerAndKeepStatus "${kswsawRunUser}" ":" "$kswsawBinAbs" "$kswsawBin")";
	kswsawSigRet=0;
	if [ "$(getCSVValue "${kswsawStatusEntry}" ${serverAndKeepStatusServerStatusColumnId} ":")" = "0" ]; then
		kswsawServerPid="$(getCSVValue "${kswsawStatusEntry}" ${serverAndKeepStatusServerPIDColumnId} ":")";
		if [ -n "${kswsawServerPid}" ]; then
			test "${cfg_dbg:-0}" -ge 1 && printf "sending signal to PID (%s)\n" "${kswsawServerPid}" >&2;
			SignalToServer "${kswsawSigToSend}" "${kswsawSigToSendName}" "${kswsawServerPid}" "kswsawKilledPid" "${kswsawBin}"
			kswsawSigRet=$?;
		fi
	fi;
	termExitCode=0;
	if [ "$kswsawSigRet" -eq 0 ] && [ -n "${kswsawKilledPid}" ] && [ "${kswsawWaitCount:-0}" -gt 0 ]; then
		WaitOnTermination "${kswsawWaitCount}" "${kswsawKilledPid}"
		termExitCode=$?;
		test $termExitCode -eq 0 && removeFiles "${PID_FILE}" "${RUNUSERFILE}"
	fi
	return $termExitCode;
}

# param 1: run user hint
#
# variables used: RUNUSERFILE, RUN_USERs
#
# output best matching run user
determineRunUser()
{
	druRunUser="${1:-}";
	if [ -z "${druRunUser}" ]; then
		test -f "${RUNUSERFILE}" && druRunUser=$(cat "${RUNUSERFILE}" 2>/dev/null);
		druRunUser="${druRunUser:-${RUN_USER:-$(getUid)}}";
	fi
	echo "${druRunUser}";
}
