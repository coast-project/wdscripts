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
# generated using $> cat serverfuncs.sh | sed -n 's/^\([a-zA-Z][^(]*\)(.*$/unset -f \1/p'
unset -f LogScriptMessage
unset -f LogEnterScript
unset -f LogLeaveScript
unset -f checkProcessWithName
unset -f WaitOnTermination
unset -f SignalToServer
unset -f logMessageToFile
unset -f removeOrphanedPidFile
unset -f exitIfDisabledService
unset -f getServerStatus
unset -f getKeepwdsStatus
unset -f startWithKeep
unset -f getServerAndKeepStatus
unset -f waitForStartedServer
unset -f sendSignalToServerAndWait
unset -f determineRunUser

# log into server.msg and server.err some message
# param 1: message
#
LogScriptMessage()
{
	printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${1}" | tee -a ${ServerMsgLog} ${ServerErrLog};
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
	cpwnBinName="${1}";
	cpwnProcessArguments="${2}";
	cpwnRunUser="${3}";
	cpwnProjectDir="${4}";
	cpwnArgumentMatchMandatory=${5:-0};
	cpwnPids="";
	cpwnSuccess=0;
	cpwnFailure=1;
	cpwnReturnCode=${cpwnFailure};
	# only compare using numerical uids
	cpwnLsUserArgument="-n";
	eval "expr $cpwnRunUser + 1 >/dev/null 2>&1" || cpwnRunUser="`getUid ${cpwnRunUser}`";
	# override user comparison for root (uid=0)
	if [ "${cpwnRunUser}" = "0" ]; then
		cpwnCompareUserRE="[0-9][0-9]*";
	else
		cpwnCompareUserRE="${cpwnRunUser}";
	fi
	cpwnLsBinary=`unalias ls 2>/dev/null; type -fP ls`;
	cpwnDirCandidates="`${cpwnLsBinary} ${cpwnLsUserArgument} /proc 2>/dev/null | sed -n -e \"s|^[^ ]* *[^ ]* *${cpwnCompareUserRE} .* \([^ ]*\)\$|/proc/\1|p\"`";
	for processBaseDir in ${cpwnDirCandidates}; do
		for cwdCand in $processBaseDir/path/cwd $processBaseDir/cwd; do
			test -h $cwdCand || continue;
			# check if the project directory matches the servers working directory
			cpwnProcessCWD=`${cpwnLsBinary} -l $cwdCand 2>/dev/null | cut -d'>' -f2- | cut -d' ' -f2-`;
			test -n "${cpwnProcessCWD}" || continue;
			test "${cpwnProcessCWD}" = "${cpwnProjectDir}" || continue;
			workingDir=`dirname ${cwdCand}`;
			cpwnProcessPath="";
			cpwnCmdArgsMatched="";
			# find executable path
			for exeCand in $workingDir/a.out $workingDir/exe; do
				test -h ${exeCand} || continue;
				# get link to binary
				cpwnProcessPath=`${cpwnLsBinary} -l $exeCand 2>/dev/null| cut -d'>' -f2- | cut -d' ' -f2-`;
				# sanity check if a link to the binary is available
				test -n "${cpwnProcessPath}" || continue;
				cpwnProcessPath="`echo $cpwnProcessPath | sed -n \"\|.*${cpwnBinName}.*|p\"`";
				# check if binary matched, if it was only the surrounding shell we bail out
				test -n "${cpwnProcessPath}" || continue;
				# also check if parts of the command line match, shortcut if empty
				test -z "${cpwnProcessArguments}" && break;
				# depending on target system only one item of the list is defined
				for cpwnCmdLineTry in "$processBaseDir/psinfo" "$processBaseDir/cmdline"; do
					test -r "${cpwnCmdLineTry}" || continue;
					# only use the last part (basename) of the command
					cpwnCmdArgsMatched="`cat ${cpwnCmdLineTry} 2>/dev/null| tr '\0' ' ' | tr -d '[:cntrl:]' | grep -c \"\`basename ${cpwnBinName:-/}\` ${cpwnProcessArguments}\"`";
					# test if the command argument matched
					test -n "${cpwnCmdArgsMatched}" || continue;
				done
				test -n "${cpwnCmdArgsMatched}" && break;
			done
			if [ -z "${cpwnProcessPath}" ]; then
				# probably a script we are looking for, check the fd's
				# in case a script was started from within a shell instance
				#  we need to check for fd entries to find the real executable
				# linux: fd entries link to files directly, mode can not be used to distinguish between files and special devices
				# solaris: fd entries are used to lookup within /proc/*/path/, mode (not link and executable) can be used
				for fdCand in ${processBaseDir}/fd/*; do
					test ! -h "${fdCand}" && test -x "${fdCand}" && fdCand="${workingDir}/`basename ${fdCand:-/}`";
					cpwnProcessPath=`${cpwnLsBinary} -l $fdCand 2>/dev/null| cut -d'>' -f2- | cut -d' ' -f2-`;
					cpwnProcessPath="`echo $cpwnProcessPath | sed -n \"\|.*${cpwnBinName}.*|p\"`";
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
			if [ ${cpwnArgumentMatchMandatory} -eq 0 -o -n "${cpwnCmdArgsMatched}" ]; then
				echo "`basename ${processBaseDir:-/}`";
				return $cpwnSuccess;
			fi
		done; # cwdCand
	done; # processBaseDir
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
	wotPids="$@";
	wotOrgPids="$@";
	wotHasStopped=0;
	wotReturnCode=1;
	wotNewPids="";
	if [ $PRINT_DBG -ge 2 ]; then echo "wotPids [${wotPids}]"; fi;
	wotWaitCount=`expr $wotWaitCount / 2`;
	while [ $wotWaitCount -ge 0 ]; do
		wotWaitCount=`expr $wotWaitCount - 1`;
		wotNewPids="";
		for curPid in $wotPids; do
			if [ $PRINT_DBG -ge 2 ]; then echo "curPid [${curPid}]"; fi;
			checkProcessId "${curPid}"
			if [ $? -eq 1 ]; then
				wotHasStopped=`expr $wotHasStopped + 1`;
			else
				if [ -n "${wotNewPids}" ]; then wotNewPids="${wotNewPids} ";fi;
				wotNewPids="${wotNewPids}${curPid}";
			fi
		done;
		if [ -n "${wotNewPids}" ]; then
			wotPids="${wotNewPids}";
			if [ $PRINT_DBG -ge 2 ]; then echo "new wotPids [${wotPids}]"; fi;
		else
			break;
		fi
		printf "."
		sleep 2
	done
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
	printf "server %s on %s with pid(s) %s..." "${SERVERNAME}" "${HOSTNAME}" "${wotOrgPids}" >> ${ServerMsgLog};
	if [ ${wotHasStopped} -ge 1 ]; then
		printf "stopped\n" >> ${ServerMsgLog};
		wotReturnCode=0;
	else
		printf "still running!\n" >> ${ServerMsgLog};
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
			checkProcessId "${stsPidToReturn}"
			if [ $? -eq 0 ]; then
				if [ $stsDoFirst -eq 1 ]; then
					printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog} >&2
					printf "sending SIG%s (%s) to process (%s)" "${stsSigName}" "${stsSigNum}" "${stsBinName}" | tee -a ${ServerMsgLog} ${ServerErrLog} >&2
					stsDoFirst=0;
				fi
				if [ -n "${kErrMsg}" ]; then kErrMsg="${kErrMsg} ";fi
				kErrMsg="$kErrMsg"`kill -${stsSigNum} ${stsPidToReturn}`;
				killReturnCode=$?
				printf ", %s" "${stsPidToReturn}" | tee -a ${ServerMsgLog} ${ServerErrLog} >&2
				if [ $killReturnCode -eq 0 ]; then
					if [ -n "${stsPidKilled}" ]; then stsPidKilled="${stsPidKilled} "; fi
					stsPidKilled="${stsPidKilled}${stsPidToReturn}";
				else
					printf "(failed)" "${stsPidToReturn}" | tee -a ${ServerMsgLog} ${ServerErrLog} >&2
					stsReturnCode=2;
				fi
			fi
		done
		if [ -n "${kErrMsg}" ]; then
			printf "\n Error(s) [%s]" "${kErrMsg}" | tee -a ${ServerMsgLog}
		fi
		printf "\n" | tee -a ${ServerMsgLog} ${ServerErrLog}
		if [ $stsDoFirst -eq 1 ]; then
			printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
			printf "process (%s) is not running anymore\n" "${stsBinName}" | tee -a ${ServerMsgLog} >&2
			stsReturnCode=1;
		fi
	else
		printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
		printf "WARNING: no PID(s) given for process (%s)\n" "${stsBinName}" | tee -a ${ServerMsgLog} >&2;
		stsReturnCode=1;
	fi
	eval ${stsExpVar}="${stsPidKilled}";
	export ${stsExpVar}
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
	printf "%s %s: %s%s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${lmMessage}" "${lmMessageTail}" >> ${lmLogfileName};
}

# param 1: pidfilename
# param 2: infotext
removeOrphanedPidFile()
{
	ropfFilename="${1}";
	test -n "${ropfFilename}" || return 0;
	test -f "${ropfFilename}" || return 0;
	logMessageToFile "${2}"
	rm -f ${ropfFilename} 2>/dev/null;
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
	if [ -n "${RUN_SERVICE}" -a ${RUN_SERVICE:-1} -eq 0 ]; then
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
	gssPid="`getPIDFromFile \"${gssPidFile}\"`";
	test -n "${gssPid}" && checkProcessId "${gssPid}" && echo "${gssPid}" && return 0;
	# information from file was useless, delete it
	test -f "${gssPidFile}" && removeOrphanedPidFile ${gssPidFile} "INFO: orphaned server-pidfile found but server: ${gssServername} was not running anymore"
	# start search with maximum specification and the reduce
	for gssSearchInPS in "${gssWdsBinAbs}" "${gssWdsBin}"; do
		gssPid="`checkProcessWithName \"${gssSearchInPS}\" \"${gssServername}\" \"${gssRunUser}\" \"${PROJECTDIRABS}\" 1`" || continue
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
	gksPid="`getPIDFromFile \"${gksPidFile}\"`";
	test -n "${gksPid}" && checkProcessId "${gksPid}" && echo "${gksPid}" && return 0;
	# information from file was useless, delete it
	test -f "${gksPidFile}" && removeOrphanedPidFile ${gksPidFile} "INFO: orphaned keepwds-pidfile found but keepwds.sh is not running anymore"
	gksPid="`checkProcessWithName \"${gksScriptname}\" \"\" \"${gksRunUser}\" \"${PROJECTDIRABS}\" 0`"
	gksCheckStatus=$?;
	echo "${gksPid}";
	return ${gksCheckStatus};
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
	test $PRINT_DBG -ge 1 && swkScriptDebug="-D"
	swkAmIroot=0;
	test `getUid` -eq 0 && swkAmIroot=1;
	swkServerArguments="$@";
	if [ $swkAmIroot -eq 1 -a -n "${swkRunUser}" ]; then
		# must adjust the owner of the probably newly created server-log-files
		if [ -n "${ServerMsgLog}" -a -f ${ServerMsgLog} ]; then chown ${swkRunUser} ${ServerMsgLog}; fi;
		if [ -n "${ServerErrLog}" -a -f ${ServerErrLog} ]; then chown ${swkRunUser} ${ServerErrLog}; fi;
		# write run-user into special file for later server destruction
		echo "${swkRunUser}" > "${swkRunUserFile}";
		chown ${swkRunUser} ${swkRunUserFile};
		su ${swkRunUser} -c "${swkKeepwdsFile} ${swkScriptDebug} -- ${swkServerArguments} >/dev/null 2>&1 & echo \$! > ${swkKeepPidFile}";
	else
		${swkKeepwdsFile} ${swkScriptDebug} -- ${swkServerArguments} >/dev/null 2>&1 &
		swkPidOfKeepwds=$!;
		echo $swkPidOfKeepwds > ${swkKeepPidFile};
	fi;
	swkPidOfKeepwds="`getPIDFromFile ${swkKeepPidFile}`";
	echo "${swkPidOfKeepwds}";
}

serverAndKeepStatusServerPIDColumnId=1;
serverAndKeepStatusServerStatusColumnId=2;
serverAndKeepStatusKeepPIDColumnId=3;
serverAndKeepStatusKeepStatusColumnId=4;

# param 1: user name to find running instances for
# param 2: separator, default ':'
#
# required variables: PID_FILE, WDS_BINABS, WDS_BIN, SERVERNAME, KEEPPIDFILE, KEEP_SCRIPT
#
getServerAndKeepStatus()
{
	gsaksRunUser="${1}";
	gsaksSep="${2:-:}";
	gsaksServerPid=`getServerStatus "${PID_FILE}" "${WDS_BINABS}" "${WDS_BIN}" "${SERVERNAME}" "${gsaksRunUser}"`;
	gsaksServerStatus=$?
	gsaksKeepPid=`getKeepwdsStatus "${KEEPPIDFILE}" "${KEEP_SCRIPT}" "${gsaksRunUser}"`;
	gsaksKeepStatus=$?
	echo "${gsaksServerPid}${gsaksSep}${gsaksServerStatus}${gsaksSep}${gsaksKeepPid}${gsaksSep}${gsaksKeepStatus}";
}

# param 1: user to run server as
# param 2: time to wait for startup, default 10s
#
# return 0 in case
waitForStartedServer()
{
	wfssRunUser="${1}";
	wfssWaitTime=${2:-10};
	wfssSleepTime=2;
	wfssStatusEntry="`getServerAndKeepStatus ${wfssRunUser}`"
	wfssWaitCount=`expr $wfssWaitTime / $wfssSleepTime`;
	while [ $wfssWaitCount -ge 0 ]; do
		wfssWaitCount=`expr $wfssWaitCount - 1`;
		test "`getCSVValue \"${wfssStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" && test "`getCSVValue \"${wfssStatusEntry}\" ${serverAndKeepStatusKeepStatusColumnId} \":\"`" = "0" && return 0;
		printf "." >&2
		sleep $wfssSleepTime;
		wfssStatusEntry="`getServerAndKeepStatus ${wfssRunUser}`"
	done
	return 1
}

# param 1: numeric signal to send
# param 2: signal name
# param 3: user the server runs as
# param 4: time to wait on termination
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
	kswsawKilledPid="";
	kswsawStatusEntry="`getServerAndKeepStatus ${kswsawRunUser}`";
	kswsawSigRet=0;
	if [ "`getCSVValue \"${kswsawStatusEntry}\" ${serverAndKeepStatusServerStatusColumnId} \":\"`" = "0" ]; then
		kswsawServerPid="`getCSVValue \"${kswsawStatusEntry}\" ${serverAndKeepStatusServerPIDColumnId} \":\"`";
		if [ -n "${kswsawServerPid}" ]; then
			test ${cfg_dbg:-0} -ge 1 && printf "sending signal to PID (%s)\n" "${kswsawServerPid}" >&2;
			SignalToServer ${kswsawSigToSend} "${kswsawSigToSendName}" "${kswsawServerPid}" "kswsawKilledPid" "${WDS_BIN}"
			kswsawSigRet=$?;
		fi
	fi;
	termExitCode=0;
	if [ $kswsawSigRet -eq 0 -a -n "${kswsawKilledPid}" -a ${kswsawWaitCount} -gt 0 ]; then
		WaitOnTermination ${kswsawWaitCount} "${kswsawKilledPid}"
		termExitCode=$?;
		test $termExitCode -eq 0 && removeFiles ${PID_FILE} ${RUNUSERFILE}
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
	druRunUser="${1}";
	if [ -z "${druRunUser}" ]; then
		test -f "${RUNUSERFILE}" && druRunUser=`cat ${RUNUSERFILE} 2>/dev/null`;
		druRunUser="${druRunUser:-${RUN_USER:-`getUid`}}";
	fi
	echo "${druRunUser}";
}
