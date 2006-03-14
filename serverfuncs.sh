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

# log into server.msg and server.err that we are entering the script
#
LogEnterScript()
{
	printf "%s %s: ---- entering ----\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
}

# log into server.msg and server.err that we are leaving the script
#
# param $1 exit code to log
#
LogLeaveScript()
{
	locRetCode=${1};
	printf "%s %s: ---- leaving (%s) ----\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${locRetCode}" | tee -a ${ServerMsgLog} ${ServerErrLog};
}

# check if a process matching the WDS_BIN pattern and the given user is in the process list
#
# param $1 path/name of process to lookup in process list
# param $2 name of user the process is running as
# param $3 name of variable to put retrieved pids into, must be defined and initialized in outer scope
#
# return 1 in case such a process exists, 0 otherwise
#
checkProcessWithName()
{
	local locBinName="${1}";
	local locRunUser="${2}";
	local locExpVar="${3}";
	local locRet=0;
	local locPids="";
	local locUser="";
	if [ -n "${locRunUser}" ]; then
		locUser="-u ${locRunUser}";
	else
		locUser="-e";
	fi
	for lPid in `ps ${locUser} -o pid,args | grep "${locBinName}" | grep -v grep | awk '{print $1}'`; do
		if [ "$lPid" = "PID" ]; then
			continue;
		fi
		if [ -n "${locPids}" ]; then 
			locPids="${locPids} ";
		fi
		locPids="${locPids}${lPid}";
		locRet=1;
	done
	eval ${locExpVar}='${locPids}';
	return $locRet;
}

# wait on termination of given process ids
#
# param $1 list of process ids, whitespace separated
# param $2 max time to wait on termination in seconds
#
# return:
#  0 in case the process stopped within the time given
#  1 if the process was still alive after the time given
#
WaitOnTermination()
{
	local locPids="${1}";
	local locOrgPids="${1}";
	local locWaitCount=${2};
	local locHasStopped=0;
	local locRet=1;
	local newPids="";
	if [ $cfg_dbg -eq 1 ]; then echo "locPids [${locPids}]"; fi;
	printf "waiting on server termination "
	locWaitCount=$(( $locWaitCount / 2 ));
	while [ $locWaitCount -ge 0 ]; do
		locWaitCount=$(( $locWaitCount - 1 ));
		newPids="";
		for curPid in $locPids; do
			if [ $cfg_dbg -eq 1 ]; then echo "curPid [${curPid}]"; fi;
			checkProcessId "${curPid}"
			if [ $? -eq 0 ]; then
				locHasStopped=$(( $locHasStopped + 1 ));
			else
				if [ -n "${newPids}" ]; then newPids="${newPids} ";fi;
				newPids="${newPids}${curPid}";
			fi
		done;
		if [ -n "${newPids}" ]; then
			locPids="${newPids}";
			if [ $cfg_dbg -eq 1 ]; then echo "new locPids [${locPids}]"; fi;
		else
			break;
		fi
		printf "."
		sleep 2
	done
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog};
	printf "server %s on %s with pid(s) %s..." "${SERVERNAME}" "${HOSTNAME}" "${locOrgPids}" | tee -a ${ServerMsgLog} ${ServerErrLog};
	if [ ${locHasStopped} -ge 1 ]; then
		printf "%s\n" "done"
		printf "stopped\n" | tee -a ${ServerMsgLog} ${ServerErrLog};
		locRet=0;
	else
		printf "%s\n" "not successful, server did not terminate in given time"
		printf "still running!\n" | tee -a ${ServerMsgLog} ${ServerErrLog};
	fi
	return $locRet;
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
	local locSigNum=${1};
	local locSigName=${2};
	local locPids="${3}";
	local locExpVar="${4}";
	local locBinName="${5:-?}";
	local locPidKilled="";
	local locRet=0;
	local locPid=0;
	local kErrMsg="";
	local doFirst=1;
	if [ -n "${locPids}" ]; then
		for locPid in ${locPids}; do
			checkProcessId "${locPid}"
			if [ $? -ne 0 ]; then
				if [ $doFirst -eq 1 ]; then
					printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" | tee -a ${ServerMsgLog} ${ServerErrLog}
					printf "sending SIG%s (%s) to process (%s)" "${locSigName}" "${locSigNum}" "${locBinName}" | tee -a ${ServerMsgLog} ${ServerErrLog}
					doFirst=0;
				fi
				if [ -n "${kErrMsg}" ]; then kErrMsg="${kErrMsg} ";fi
				kErrMsg="$kErrMsg"`kill -${locSigNum} ${locPid}`;

				printf ", %s" "${locPid}" | tee -a ${ServerMsgLog} ${ServerErrLog}
				if [ $? -eq 0 ]; then
					if [ -n "${locPidKilled}" ]; then locPidKilled="${locPidKilled} "; fi
					locPidKilled="${locPidKilled}${locPid}";
				else
					printf "(failed)" "${locPid}" | tee -a ${ServerMsgLog} ${ServerErrLog}
					locRet=2;
				fi
			fi
		done
		if [ -n "${kErrMsg}" ]; then
			printf "\n Error(s) [%s]" "${kErrMsg}" | tee -a ${ServerMsgLog}
		fi
		printf "\n" | tee -a ${ServerMsgLog} ${ServerErrLog}
		if [ $doFirst -eq 1 ]; then
			printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog}
			printf "process (%s) is not running anymore\n" "${locBinName}" | tee -a ${ServerMsgLog}
			locRet=1;
		fi
	else
		printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
		printf "WARNING: no PID(s) given for process (%s)\n" "${locBinName}" "${}" | tee -a ${ServerMsgLog};
		locRet=1;
	fi
	eval ${locExpVar}='${locPidKilled}';
	return $locRet;
}
