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
# Variables used in this script:
#  $_locExists - might evaluate to 0, 1 or 4, depending on several situations (is the server, wdapp, not running but keepwds.sh still running? Was the server started with startwds.sh?
#                Is the server, wdapp, running but keepwds.sh dead?)
#  $locProcOK - tells if a process is running or not
#  $my_keeppidfile - contains the file location of keepwds.sh
#  $my_keeppid - contains the PID of the keepwds.sh
#  $wd_pidfile - contains the file with the PID for a Coast Application
#  $wdpid - contains the PID of the Coast Application
#

org_name=$0;

if [ "$1" = "-D" ]; then
	PRINT_DBG=1
	cfg_dbgopt="-D";
	shift
else
	PRINT_DBG=0
	cfg_dbgopt="";
fi
export PRINT_DBG

# dereference a file/path - usually a link - and find its real origin
#
# param $1 is the file/path to dereference
# param $2 the name of the variable to put the dereferenced file/path into
#
# output exporting dereferenced file/path into given name ($2)
# returning 1 in case the given name was linked, 0 otherways
deref_links()
{
	loc_name=${1};
	ret_var=${2};
	test ! -d $loc_name;
	is_dir=$?
	is_link=0;
	cur_path=`dirname ${loc_name}`
	while [ -h $loc_name -a `ls -l $loc_name 2>/dev/null | grep -c "^l" ` -eq 1 ]; do
		if [ $PRINT_DBG -eq 1 ]; then printf $loc_name; fi
		loc_name=`ls -l $loc_name | grep "^l" | cut -d'>' -f2 -s | sed 's/^ *//'`;
		if [ $is_dir -eq 1 ]; then
			loc_name=${cur_path}/${loc_name}
		fi
		if [ $PRINT_DBG -eq 1 ]; then echo ' ['${1}'] was linked to ['$loc_name']'; fi
		cur_path=`dirname ${loc_name}`
		is_link=1;
	done
	eval ${ret_var}="$loc_name";
	return $is_link;
}

# retrieve value of variable usually set from config.sh
#
# param $1 project path to start from
# param $2 script directory from where to execute config.sh
# param $3 name of variable to get value from
# param $4 name of output variable getting the retrieved value
#
# output exporting value into given variable name ($4)
getconfigvar()
{
	loc_prjPath=${1};
	loc_scDir=${2};
	loc_name=${3};
	ret_var=${4};
	loc_name=`/bin/sh -c "cd ${loc_prjPath}; mypath=${loc_scDir}; . ${loc_scDir}/config.sh >/dev/null 2>&1; eval \"echo $\"$loc_name"`
	eval ${ret_var}="$loc_name";
}

# check if a given process id still appears in process list
#
# param $1 is the process id to check for
#
# returning 1 if process still exists, 0 if the process is not listed anymore
checkProcessId()
{
	loc_pid=${1};
	loc_ret=1;
	if [ -n "$loc_pid" ]; then
		# check if pid still exists
		ps -p ${loc_pid} > /dev/null
		if [ $? -ne 0 ]; then
			echo 'process with pid:'${loc_pid}' has gone!';
			loc_ret=0;
		fi;
	else
		loc_ret=0;
	fi
	return $loc_ret;
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
	locBinName="${1}";
	locRunUser="${2}";
	locExpVar="${3}";
	locRet=0;
	locPids="";
	locUser="";
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

# Returns:
# 0, if the server isn't running
# 1, if the server was started using startwds.sh instead of bootScript.sh
# 4, if keepwds.sh doesn't run, but the server is running
checkPidFilesAndServer()
{
	# check if the keepwds script is still running
	_locExists=0;
	if [ -n "$my_keeppid" ]; then       # keepswds.sh is still running
		if [ $locKeepOk -eq 0 ]; then   # but the wdapp is not running
			outmsg="INFO: orphaned keepwds-pidfile found but keepwds.sh is not running anymore";
			printf "%s\n" "${outmsg}";
			printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
			my_keeppid="";
			rm -f ${my_keeppidfile};
		fi;
	fi
	# double check to see if someone started the process using startwds.sh instead of using bootScript.sh
	if [ -n "$wdpid" ]; then  # this means the server is running
		if [ $locProcOk -eq 1 ]; then
			_locExists=1;
		else
			outmsg="INFO: orphaned server-pidfile found but server: $SERVICENAME was not running anymore";
			printf "%s\n" "${outmsg}"
			printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
			wdpid="";
			rm -f ${wd_pidfile};
		fi
	fi

	# keepwds.sh doesn't run ($my_keeppid is empty), but the server is running (which means it was started with startwds.sh or that it was started with
	# boosScript.sh but someone killed keepwds.sh),
	if [ -z "$my_keeppid" -a $_locExists -eq 1 ]; then
		outmsg="WARNING: server is running but it seems that it was not started using ${MYNAME}";
		printf "%s\n" "${outmsg}"
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
		_locExists=4;
	fi
	return $_locExists;
}

startWithKeep()
{
	_locRetPid=0;
	_amIroot=${1:-0};
	_runUser=${2};
	_runUserFile=${3};
	_keepPidFile=${4};
	_locExpVar="${5}";
	if [ $_amIroot -eq 1 -a -n "${_runUser}" ]; then
		# must adjust the owner of the probably newly created server-log-files
		chown ${_runUser} ${ServerMsgLog} ${ServerErrLog}
		# write run-user into special file for later server destruction
		echo "${_runUser}" > "${_runUserFile}"
		su ${_runUser} -c "${keep_script} ${cfg_dbgopt} >/dev/null 2>&1 & echo \$! > ${_keepPidFile}"
	else
		eval "${keep_script} ${cfg_dbgopt} >/dev/null 2>&1 &"
		_locRetPid=$!;
		echo $_locRetPid > ${_keepPidFile};
	fi;
	_locRetPid=`cat ${_keepPidFile} 2>/dev/null`;
	eval ${_locExpVar}=${_locRetPid};
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
	_locPids="${1}";
	_locOrgPids="${1}";
	_locWaitCount=${2};
	_locHasStopped=0;
	_locRet=1;
	_newPids="";
	if [ $PRINT_DBG -eq 1 ]; then echo "_locPids [${_locPids}]"; fi;
	_locWaitCount=`expr $_locWaitCount / 2`;
	while [ $_locWaitCount -ge 0 ]; do
		_locWaitCount=`expr $_locWaitCount - 1`;
		_newPids="";
		for curPid in $_locPids; do
			if [ $PRINT_DBG -eq 1 ]; then echo "curPid [${curPid}]"; fi;
			checkProcessId "${curPid}"
			if [ $? -eq 0 ]; then
				_locHasStopped=`expr $_locHasStopped + 1`;
			else
				if [ -n "${_newPids}" ]; then _newPids="${_newPids} ";fi;
				_newPids="${_newPids}${curPid}";
			fi
		done;
		if [ -n "${_newPids}" ]; then
			_locPids="${_newPids}";
			if [ $PRINT_DBG -eq 1 ]; then echo "new _locPids [${_locPids}]"; fi;
		else
			break;
		fi
		printf "."
		sleep 2
	done
	printf "%s %s: " "`date +%Y%m%d%H%M%S`" "${MYNAME}" >> ${ServerMsgLog};
	printf "%s with pid(s) %s..." "${my_unique_text}" "${_locOrgPids}" >> ${ServerMsgLog};
	if [ ${_locHasStopped} -ge 1 ]; then
		printf "stopped\n" >> ${ServerMsgLog};
		_locRet=0;
	else
		printf "still running!\n" >> ${ServerMsgLog};
	fi
	return $_locRet;
}

cleanfiles()
{
	rm -f ${my_keeppidfile} ${wd_pidfile} ${my_runuserfile};
}

deref_links "$0" "derefd_name"
isLink=$?
if [ $isLink -eq 1 ]; then
	link_name=$0;
fi
scriptPath=`dirname $derefd_name`;
derefd_name=`basename $derefd_name`;
MYNAME=${derefd_name};
SCRIPTDIR=`cd ${scriptPath}; pwd`;
HOSTNAME=`(uname -n) 2>/dev/null` || HOSTNAME="unkown"
cfg_waitcount=1200;

# getting the projectpath and -name is not simple because we have at least three ways
#  to get executed:
#  1. relative, path expanded from shell using PATH variable
#  2. absolute
#  3. through a link to the real script
#
# The third case currently works fine but implicitly assumes that a 'cd ..' is the correct project directory.
# But this is not true for the first two cases where we actually reside in the project directory at call time.
# Therefore I will do a check on an existing config* directory to see where we are.
#
prj_path=`dirname $scriptPath`
prj_pathabs=`cd $prj_path; pwd`
if [ "`echo $org_name|cut -c1`" != "/" ]; then
	# script was started with relative path
	# -> must set prj_path again to ensure proper detection of SERVICENAME
	# -> set scriptPath to SCRIPTDIR to ensure a script can unambigously identified in the process list
	prj_path=${prj_pathabs};
	scriptPath=${SCRIPTDIR};
fi
keep_script=${scriptPath}/keepwds.sh;
stop_script=${scriptPath}/stopwds.sh;
softstart_script=${scriptPath}/SoftRestart.sh;

if [ -n "${prj_path}" ]; then
	getconfigvar "${prj_path}" "${SCRIPTDIR}" CONFIGDIR tmp_CfgDir
	if [ $PRINT_DBG -eq 1 ]; then echo "configdir(1) from ${prj_path} [${tmp_CfgDir}]"; fi;
	if [ "${tmp_CfgDir}" = "." ]; then
		prj_path=`pwd`;
		getconfigvar "${prj_path}" "${SCRIPTDIR}" CONFIGDIR tmp_CfgDir
		if [ $PRINT_DBG -eq 1 ]; then echo "configdir(2) from ${prj_path} [${tmp_CfgDir}]"; fi;
	fi;
else
	outmsg="ERROR: project path could not be evaluated, exiting!";
	printf "%s\n" "${outmsg}"
	printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
	exit 4;
fi;

deref_links "$prj_path" "prj_name"
prj_name=`basename ${prj_name}`
my_uid=`id | cut -d '(' -f1 | cut -d '=' -f2`
test ! "$my_uid" -eq 0
am_I_root=$?

SERVICENAME=$prj_name
getconfigvar "${prj_path}" "${SCRIPTDIR}" LOGDIR my_logdir
my_logdir=${prj_path}/${my_logdir:=.}
my_keeppidfile=${my_logdir}/.$SERVICENAME.keepwds.pid
my_runuserfile=${my_logdir}/.RunUser
getconfigvar "${prj_path}" "${SCRIPTDIR}" PID_FILE wd_pidfile
getconfigvar "${prj_path}" "${SCRIPTDIR}" RUN_USER my_runuser
getconfigvar "${prj_path}" "${SCRIPTDIR}" RUN_SERVICE run_service
my_unique_text="Coast server: $SERVICENAME"
getconfigvar "${prj_path}" "${SCRIPTDIR}" ServerMsgLog ServerMsgLog
getconfigvar "${prj_path}" "${SCRIPTDIR}" ServerErrLog ServerErrLog
getconfigvar "${prj_path}" "${SCRIPTDIR}" WDS_BIN wds_bin
getconfigvar "${prj_path}" "${SCRIPTDIR}" WDS_BINABS wds_binabs
getconfigvar "${prj_path}" "${SCRIPTDIR}" SERVERNAME my_servername

locWDS_BIN=$wds_bin".*"${my_servername};
locWDS_BINABS=$wds_binabs".*"${my_servername};

if [ $PRINT_DBG -eq 1 ]; then
	echo "I am executing in ["${PWD}"]";
	for varname in prj_name prj_path prj_pathabs scriptPath keep_script stop_script softstart_script my_logdir link_name MYNAME my_keeppidfile wd_pidfile my_runuserfile my_runuser my_uid ServerMsgLog ServerErrLog SERVICENAME run_service wds_bin wds_binabs locWDS_BIN locWDS_BINABS; do
		locVar="echo $"$varname;
		locVarVal=`eval $locVar`;
		if [ -n "${locVarVal}" ]; then
			printf "%-16s: [%s]\n" $varname "$locVarVal"
		fi
	done
fi

rc_done="..done"
rc_running="..running"
rc_failed="..failed"
rc_dead="..dead"
rc_notExist="..not running"
rc_notPossible="..not possible, server not running"

return=$rc_done

if [ -f "$my_keeppidfile" ]; then my_keeppid=`cat ${my_keeppidfile} 2>/dev/null`; fi
if [ -f "$wd_pidfile" ]; then wdpid=`cat ${wd_pidfile} 2>/dev/null`; fi

checkProcessId ${my_keeppid};
locKeepOk=$?;
if [ $locKeepOk -eq 0 -a -n "${keep_script}" ]; then
	checkProcessWithName "${keep_script}" "${my_runuser}" my_keeppid
	locKeepOk=$?;
fi
checkProcessId ${wdpid};
locProcOk=$?;
if [ $locProcOk -eq 0 -a -n "${locWDS_BIN}" ]; then
	# Must replace locWDS_BIN by locWDS_BINABS, to enable 2 instances of the same server to run in the same machine. Otherwise, when we try to start
	# the 2nd server instance "checkProcessWithName bin.SunOS_5.10/wdapp user wdpid" will return that the server already runs! Ex:
	# wds_bin         : [bin.SunOS_5.10/wdapp]
	# wds_binabs      : [/home/myApp_norm/bin.SunOS_5.10/wdapp]
	# wds_binabs      : [/home/myApp_fast/bin.SunOS_5.10/wdapp]
	checkProcessWithName "${locWDS_BINABS}" "${my_runuser}" wdpid
	locProcOk=$?;
	if [ $locProcOk -eq 0 -a "${locWDS_BIN}" != "${locWDS_BINABS}" ]; then
		checkProcessWithName "${locWDS_BINABS}" "${my_runuser}" wdpid
		locProcOk=$?;
	fi
fi
locCommand="$1";

# do a change dir into the project directory, not to start any script from the wrong location!
cd $prj_path 2>/dev/null
if [ "`pwd`" != "$prj_path" -a "`pwd`" != "$prj_pathabs" ]; then
	echo "ERROR: could not change into project directory [$prj_path], current directory [`pwd`]";
	exit 4;
fi

checkPidFilesAndServer
loc_Exists=$?;				# set to the exit status of the last called method, e.g. checkPidFilesAndServer
ret_pid=0;
loc_CommandText="";

case "$locCommand" in
	start)
		loc_CommandText="Starting";
	;;
	stop)
		loc_CommandText="Stopping";
	;;
	status)
		loc_CommandText="Status of";
	;;
	status)
		loc_CommandText="Status of";
	;;
	restart)
		loc_CommandText="Restarting";
	;;
	reload)
		loc_CommandText="Reloading";
	;;
	*)
		loc_CommandText="";
	;;
esac

outmsg="${loc_CommandText} ${my_unique_text}";

# check if we have to execute anything depending on RUN_SERVICE setting
# -> this scripts execution will only be disabled when RUN_SERVICE is set to 0
rc_ServiceDisabled=" => will not execute, because it was disabled (RUN_SERVICE=0)!"
if [ -n "${run_service}" -a ${run_service:-1} -eq 0 -a -n "${loc_CommandText}" ]; then
	return=$rc_ServiceDisabled;
	printf "%s %s: %s" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
	printf "%s\n" "${return}" >> ${ServerMsgLog};
	echo "${outmsg}${return}"
	exit 7;
fi

case "$locCommand" in
	start)
		if [ $loc_Exists -eq 4 ]; then
			exit $loc_Exists;
		fi;
		cleanfiles;
		if [ $am_I_root -eq 1 -a -n "${my_runuser}" ]; then
			outmsg="${outmsg} as ${my_runuser}";
		fi
		printf "%s" "${outmsg}"
		printf "%s %s: %s" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog};
		if [ -n "$my_keeppid" -o $loc_Exists -eq 1 ]; then
			printf " (keep-pid:%s)" "$my_keeppid" | tee -a ${ServerMsgLog};
			return=$rc_failed", already running, try stop first!";
			printf "%s\n" "${return}" >> ${ServerMsgLog};
		else
			printf "\n" >> ${ServerMsgLog};
			startWithKeep $am_I_root "${my_runuser}" "${my_runuserfile}" "${my_keeppidfile}" "ret_pid";
			if [ $ret_pid -eq 0 ]; then return=$rc_failed; fi
			printf " (keep-pid:%d)" "$ret_pid"
		fi
	;;
	stop)
		outmsg="${outmsg} (keep-pid:${my_keeppid:-?}) (server-pid:${wdpid:-?})";
		printf "%s" "${outmsg}"
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog}
		if [ $locKeepOk -eq 1 ]; then
			# we need to kill the keepwds.sh script to terminate the server and not restart it again
			# it can take up to ten seconds until the script checks the signal and terminates the server
			kill -15 $my_keeppid;
			WaitOnTermination "${my_keeppid} ${wdpid}" ${cfg_waitcount}
		else
			if [ $locProcOk -eq 1 ]; then
				eval "${stop_script} ${cfg_dbgopt} -w ${cfg_waitcount} >/dev/null 2>&1";
				if [ $? -ne 0 ]; then
					# try hardkill to ensure it died
					eval "${stop_script} ${cfg_dbgopt} -K >/dev/null 2>&1 || return=$rc_failed";
				fi;
			else
				# no server and no keepwds
				return=$rc_notExist;
			fi;
		fi;
		cleanfiles
	;;
	status)
		# check if keepwds.sh script is still in process list and
		#  the main pid of the wdserver is still present too
		outmsg="${outmsg} (keep-pid:${my_keeppid:-?}) (server-pid:${wdpid:-?})";
		printf "%s" "${outmsg}"
		if [ $loc_Exists -eq 0 ]; then
			# no server and no keepwds
			return=$rc_notExist;
		else
			return=$rc_running;
		fi;
		if [ $locProcOk -eq 0 -a $locKeepOk -eq 1 ]; then
			return=$rc_dead
		fi
		printf "%s %s: %s%s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" "${return}" >> ${ServerMsgLog}
	;;
	restart)
		outmsg="${outmsg} (keep-pid:${my_keeppid:-?}) (server-pid:${wdpid:-?})";
		printf "%s" "${outmsg}"
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog}
		# the keepwds.sh script will automatically restart the server when it was down
		if [ $locProcOk -eq 1 ]; then
			eval "${stop_script} ${cfg_dbgopt} -w ${cfg_waitcount} >/dev/null 2>&1";
			if [ $? -ne 0 ]; then
				# try hardkill to ensure it died
				eval "${stop_script} ${cfg_dbgopt} -K >/dev/null 2>&1 || return=$rc_failed";
			fi;
		fi;
		if [ $loc_Exists -eq 4 -o $locKeepOk -eq 0 ]; then
			# keepwds.sh was not present, start server again using keepwds.sh
			startWithKeep $am_I_root "${my_runuser}" "${my_runuserfile}" "${my_keeppidfile}" "ret_pid";
			if [ $ret_pid -eq 0 ]; then return=$rc_failed; fi
		fi;
	;;
	reload)
		outmsg="${outmsg} (keep-pid:${my_keeppid:-?}) (server-pid:${wdpid:-?})";
		printf "%s" "${outmsg}"
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog}
		if [ $loc_Exists -eq 0 ]; then
			# no server and no keepwds
			return=$rc_notPossible;
		else
			eval "${softstart_script} ${cfg_dbgopt} >/dev/null 2>&1 || return=$rc_failed";
		fi;
	;;
	*)
		outmsg="${loc_CommandText}: ${MYNAME} {start|stop|status|restart|reload}, given [$@]";
		echo $outmsg;
		printf "%s %s: %s\n" "`date +%Y%m%d%H%M%S`" "${MYNAME}" "${outmsg}" >> ${ServerMsgLog}
		exit 1
	;;
esac

echo "$return"
exit 0
