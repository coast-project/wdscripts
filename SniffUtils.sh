# temporary file in which to store sniffaccess-scripts
SNIFFSCRIPT=./doSniffUpdate.${CURSYSTEM}

# use sniff without display
export SNIFF_BATCH=1

# param $1 is the SNiFF session id
#
# return retcode of sniff
function SniffStart
{
	echo "================== starting SNiFF ["$1"]  ===================="
	$SNIFF_DIR/bin/sniff -s $1 &
	# return retcode of background starting sniff
	return $!;
}

# param $1 is the SNiFF session id
#
function SniffQuit
{
	echo "================== quitting SNiFF ["$1"]  ===================="
cat <<EOT >${SNIFFSCRIPT}
set_timeout 20
quit
EOT
	${SNIFF_DIR}/bin/sniffaccess -s $1 <${SNIFFSCRIPT}
	rm -f ${SNIFFSCRIPT}
}

# param $1 is the SNiFF session id
# param $2 is the current login-user
#
# return 1 if sniff is running, 0 if not
function SniffCheckRunning
{
	local sessid=$1;
	local loguser=$2;
	if [ $isWindows -ne 1 ]; then
		echo "============ checking if SNiFF ["$sessid"] is running =============="
		# sniff starts a sniffappcomm process which we can use to check if it started up yet
		local loop_counter=1
		local max_count=20	# wait 20 times 2 seconds
		while [ $loop_counter -le $max_count ]; do
			loop_counter=`expr $loop_counter + 1`
			ps -u $loguser -o args | grep -v "grep" | grep -c "sniffappcomm.*$sessid" >/dev/null
			if [ $? -ne 0 ]; then
				printf ".";
				sleep 2;
			else
				# done, sniff seems to be running, but wait a little bit to be really sure
				sleep 2;
				printf "\n"
				return 1;
			fi
		done
		return 0;
	else
		# sniffaccess is always running when sniff got started
		return 1;
	fi
}

# param $1 is the SNiFF session id
# param $2 is the WE-relative path to the project
# param $3 is the projectname including extension, eg. myProject.shared
# param $4 is the WE-name, like PWE:LinuxWWW
function SniffOpenProject
{
	local prjdir=$2
	local prjname=$3
	echo "=============== loading project ["${prjname}"] in dir ["${prjdir}"]"
cat <<EOT >${SNIFFSCRIPT}
set_timeout 3600
set_workingenv $4
open_project ${prjdir}/${prjname}
exit
EOT
	$SNIFF_DIR/bin/sniffaccess -s $1 <${SNIFFSCRIPT}
	rm -f ${SNIFFSCRIPT}
}

# param $1 is the SNiFF session id
# param $2 is the projectname including extension, eg. myProject.shared
function SniffUpdateMakefiles
{
	local prjname=$2
	echo "=============== updating makefiles for ["${prjname}"]"
	# update_makefiles is a blocking access
cat <<EOT >${SNIFFSCRIPT}
set_timeout 3600
update_makefiles ${prjname}
exit
EOT
	${SNIFF_DIR}/bin/sniffaccess -s $1 <${SNIFFSCRIPT}
	rm -f ${SNIFFSCRIPT}
}

# param $1 is the SNiFF session id
# param $2 is the projectname including extension, eg. myProject.shared
function SniffCloseProject
{
	local prjname=$2
	echo "=============== closing project ["${prjname}"]"
	# close_project is a blocking access
cat <<EOT >${SNIFFSCRIPT}
set_timeout 120
close_project ${prjname}
exit
EOT
	${SNIFF_DIR}/bin/sniffaccess -s $1 <${SNIFFSCRIPT}
	rm -f ${SNIFFSCRIPT}
}

# param $1 is the name of the user, usually $USER or $LOGNAME
# param $2 is the project path, can be relative
# param $3 is the absolute project path
# param $4 is the name of the output variable
#
# output setting variable $4 to value
function SniffGetWorkingEnvsForUser
{
	local myname=$1
	export sn_myPROJPATH=${2}
	export sn_myPROJPATHABS=${3}

	# AWK-Script to parse SNIFFs WorkingEnv file (${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff)
	# this is used to find all PrivateWorkingEnvironments
	# for the current user
cat << EOF > awkin.foo
BEGIN{
	dbg=0;
	RS="WorkingEnv";
	FS="\\r?\\n";
	mstr="\\"" usrname "\\"";
	allwes="";
	projdir=ENVIRON[myEnvVar];
	projdir2=ENVIRON[myEnvVar2];
	if (curOS == "Windows")
	{
		projdir=tolower(projdir);
		projdir2=tolower(projdir2);
	}
	if (dbg) print "newprojdir:[" projdir "]";
}
{
	if (match(\$0,mstr))
	{
		for (i=1; i< NF; i++)
		{
			# get the WorkingEnv name
			if (match(\$i,"\\t*Name"))
			{
				split(\$i, ARR, "\\"");
				if (dbg) print "name is: #" ARR[2] "#";
				wename=ARR[2];
			}
			# get the root of the project
			if (match(\$i,"\\t*PWS"))
			{
				split(\$i, ARR, "\\"");
				if (dbg) print "root is: #" ARR[2] "#";
				if ( curOS == "Windows" && ARR[2] != "\$DEV_HOME")
					weroot=tolower(ARR[2]);
				else
					weroot=ARR[2];
			}
			if (match(\$i,"\\t*Platform"))
			{
				split(\$i, ARR, "\\"");
				if (dbg) print "name is: #" ARR[2] "#";
				platform=ARR[2];
			}
		}
		if (weroot != "" && (index(projdir, weroot) || index(projdir2, weroot) || weroot == "\$DEV_HOME"))
		{
			if (dbg) print "name: " wename " root: " weroot;
			allwes = allwes " " wename "&" platform "&" weroot;
		}
	}
}
END{ print allwes; }
EOF

	# try to give a selection of working environments
	# for this I have to scan ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff
	local allwe=`awk -v usrname="$myname" -v curOS="${CURSYSTEM}" -v myEnvVar="sn_myPROJPATH" -v myEnvVar2="sn_myPROJPATHABS" -v dbg=${PRINT_DBG} -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff`;
	export ${4}="`echo ${allwe}`";

	if [ ${PRINT_DBG} -eq 1 ]; then
		echo "sn_myPROJPATH: ["${sn_myPROJPATH}"]"
		echo "sn_myPROJPATHABS: ["${sn_myPROJPATHABS}"]"
		echo user: $myname
		echo "${4}: ["$allwe"]"
	fi

	unset sn_myPROJPATH;
	unset sn_myPROJPATHABS;
	rm -f awkin.foo
}

# param $1 is the SNiFF session id
# param $2 is the WE-name, like PWE:LinuxWWW
# param $3 is the name of the output variable
#
# output setting variable $3 to value
function SniffGetWorkingEnvRoot
{
	echo "=============== getting WorkingEnv-Root of WE ["${2}"]"
	local myweroot=`${SNIFF_DIR}/bin/sniffaccess -s $1 get_workingenv_root ${2}`
	# shity sniff, writes the returned value on a new line so we have to skip the characters
	# before the real value, seems that we can use echo for that...
	myweroot="`echo ${WEROOT}`";
	if [ $isWindows -eq 1 ]; then
		# need to have the root lowercased for comparison
		myweroot="`awk -v myval="${WEROOT}" '{}END{print tolower(myval)}' \$0`";
	fi
	export ${3}="${myweroot}";
}

# param $1 is the platformname from the WorkingEnvirnoment definition
# param $2 is the name of the platform output variable, tells which platform makefile is used
# param $3 is the name of the make-command output variable, tells the full make command used
#
# output setting variable $2 to value of platform
# output setting variable $3 to value of make-command
function SniffGetPlatformMakefileNameAndMakeCommand
{
	local _makefile=`cat ${SNIFF_DIR}/Preferences/Platforms/${1}.sniff | grep "[ \t]*PlatformMakefile" | awk '{ split(\$0,ARR,"\\""); print ARR[2];}'`;
	local _makecmd=`cat ${SNIFF_DIR}/Preferences/Platforms/${1}.sniff | grep "[ \t]*MakeCommand" | awk '{ split(\$0,ARR,"\\""); print ARR[2];}'`;
	# need to remove -j option of make command because some shells do not like it
	_makecmd=`echo $_makecmd | awk '{ for (i=1;i<=NF;i++) { if (!match(\$i,"-j.")) print $i" "; }}'`;
	export ${2}="${_makefile}";
	export ${3}="${_makecmd}";
}
