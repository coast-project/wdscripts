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

DNAM=`dirname $0`
if [ "$DNAM" == "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

myname=`whoami`

# load configuration for current project
. ${mypath}/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" ${mypath}/config.sh;
	exit 4;
fi

if [ -z ${SNIFF_DIR} ]; then
	printf "\nERROR: variable SNIFF_DIR not set!\n\n"
	exit 4;
fi

# try to locate the project
SNIFFPROJNAME=`cd ${PROJECTDIR} && find . -name "${PROJECTNAME}.shared" -type f ${FINDOPT}`

if [ -z ${SNIFFPROJNAME} ]; then
	echo Looking for ${PROJECTNAME}.shared not successful:
	echo trying to find SNiFF project "("'*.shared'")" in $PROJECTDIR
	SNIFFPROJNAME=`cd ${PROJECTDIR} && find . -name "*.shared" -type f ${FINDOPT}`
fi
SNIFFPROJNAME=${SNIFFPROJNAME##*/}

if [ -z ${SNIFFPROJNAME} ]; then
	echo giving up to find SNiFF project
	exit 4
fi

export LOCK_FILE=$PROJECTDIR/Build.lock
export SNIFF_SESSION_ID=${PROJECTNAME}
# use sniff without display
export SNIFF_BATCH=1

if [ "${PRINT_DBG}" == 1 ]; then
	echo ""
	echo "SNIFF_DIR: ["${SNIFF_DIR}"]"
	echo "SNIFFPROJNAME: ["${SNIFFPROJNAME}"]"
	echo "LOCK_FILE: ["${LOCK_FILE}"]"
	echo "SNIFF_SESSION_ID: ["${SNIFF_SESSION_ID}"]"
	echo "I am: ["${myname}"]"
fi

if [ -e $LOCK_FILE ] ; then
	# if the lock file is present someone is already running a build
	echo "Build is already at work or stuck"
	echo "Please remove the $LOCK_FILE manually if the build is not running anymore"
	echo " and start over again"
	exit 4
fi

cleanfiles()
{
	rm -f $LOCK_FILE;
	rm -f awkin.foo;
	rm -f SNiFFupdate.do;
}

exitproc()
{
	cleanfiles;
	kill -9 ${mySNIFF_PID};
	exit 4;
}

trap exitproc INT

touch $LOCK_FILE

cat << EOF

Please make sure the project $SNIFFPROJNAME is not already
opened in a graphical interactive SNiFF Session. SNiFF needs
exclusive access to the project while executing commands.

EOF
sleep 3

#StartSniff because it needs some time to start up
echo ================== starting SNiFF ======================
${SNIFF_DIR}/bin/sniff -s ${SNIFF_SESSION_ID} &

mySNIFF_PID=$!

cd ${PROJECTDIR}

# AWK-Script to parse SNIFFs WorkingEnv file (${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff)
# this is used to find all PrivateWorkingEnvironments
# for the current user
cat << EOF > awkin.foo
BEGIN{
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
#	print "newprojdir:[" projdir "]";
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
#				print "name is: #" ARR[2] "#";
				wename=ARR[2];
			}
			# get the root of the project
			if (match(\$i,"\\t*PWS"))
			{
				split(\$i, ARR, "\\"");
#				print "root is: #" ARR[2] "#";
				if ( curOS == "Windows" )
					weroot=tolower(ARR[2]);
				else
					weroot=ARR[2];
			}
			if (match(\$i,"\\t*Platform"))
			{
				split(\$i, ARR, "\\"");
#				print "name is: #" ARR[2] "#";
				platform=ARR[2];
			}
		}
		if (weroot != "" && (index(projdir, weroot) || index(projdir2, weroot)))
		{
#			print "name: " wename " root: " weroot;
			allwes = allwes " " wename "&" platform "&" weroot;
		}
	}
}
END{ print allwes; }
EOF

if [ ${CURSYSTEM} == "Windows" ]; then
	myPROJPATH=${PROJECTDIRNT}
	myPROJPATHABS=${PROJECTDIRNT}
else
	myPROJPATH=${PROJECTDIR}
	myPROJPATHABS=${PROJECTDIRABS}
fi
export myPROJPATH
export myPROJPATHABS

# try to give a selection of working environments
# for this I have to scan ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff
userWEs=`awk -v usrname="$myname" -v curOS="${CURSYSTEM}" -v myEnvVar="myPROJPATH" -v myEnvVar2="myPROJPATHABS" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff`

if [ "${PRINT_DBG}" == 1 ]; then
	echo "myPROJPATH: ["${myPROJPATH}"]"
	echo user: $myname
	echo projdir: ${PROJECTDIR}
	echo userWEs: ${userWEs}
fi

echo
echo Select the PrivateWorkingEnvironment in which you want to compile "("PWE-Name:RootOfWE")"
echo
select wename in ${userWEs} eXit; do
	if [ "${wename}" == "eXit" ]; then
		exitproc;
	fi
	SNIFFWE=${wename%%\&*}
	SNIFFWEROOT=${wename##*\&}
	break;
done

if [ -z ${SNIFFWE} ]; then
	echo "Can not continue without valid WorkingEnvironment!"
	exitproc
fi

echo
echo using PWE:${SNIFFWE} in ${SNIFFWEROOT}
echo

# don't need to check this on NT
if [ "${CURSYSTEM}" != "Windows" ]; then
echo ============ checking if SNiFF is running ==============
# sniff starts a sniffappcomm process which we can use to check if it started up yet
loop_counter=1
max_count=20
while test $loop_counter -le $max_count; do
	loop_counter=`expr $loop_counter + 1`
	grepret=`ps -ef | grep -v "grep" | grep -c "sniffappcomm.*${PROJECTNAME}"`
	if [ $grepret == 0 ]; then
		printf ".";
		sleep 2;
	else
		loop_counter=`expr $max_count + 1`;
		printf ".";
		sleep 2;
		printf "\n"
	fi
done
fi
sleep 5

WEROOT=`${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID}	get_workingenv_root PWE:${SNIFFWE}`
# shity sniff, writes the returned value on a new line so we have to skip the characters
# before the real value, seems that we can use echo for that...
WEROOT=`echo ${WEROOT}`
if [ ${CURSYSTEM} == "Windows" ]; then
	# need to have the root lowercased for comparison
	WEROOT=`awk -v myval="${WEROOT}" '{}END{print tolower(myval)}' \$0`;
fi
if [ "${PRINT_DBG}" == 1 ]; then
	echo "WEROOT: ["${WEROOT}"]"
fi
# cut the root part of the directory to get the part relative to WE_ROOT of SNiFF
RELSNIFFPROJ=${myPROJPATH#${WEROOT}/}
if [ "${PRINT_DBG}" == 1 ]; then
	echo "RELSNIFFPROJ: ["${RELSNIFFPROJ}"]"
fi

# setup the sniff commands to execute first
# these load the WorkingEnvironment and update the makefiles
cat << EOF > SNiFFupdate.do
set_timeout 3600  # Timeout set to 1 hour to allow some more growth
set_workingenv PWE:${SNIFFWE}
open_project ${RELSNIFFPROJ}/${SNIFFPROJNAME}
update_makefiles ${SNIFFPROJNAME}
exit
EOF

# Update makefiles & make
echo =============== updating makefiles =====================
${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID}	<SNiFFupdate.do

# OK here it comes
echo ================ cleaning targets ======================
${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID} make_project ${SNIFFPROJNAME} clean_targets

echo ========= waiting on sniff cleaning targets ============
sleep 5
printf ".";
loop_counter=1
max_count=60
while test $loop_counter -le $max_count; do
	loop_counter=`expr $loop_counter + 1`
	if [ ${CURSYSTEM} == "Windows" ]; then
		grepret=`ps -ef | grep -v "grep" | grep -c "make$"`
	else
		grepret=`ps -ef | grep -v "grep" | grep -c "make.*clean_targets$"`
	fi
	if [ ! $grepret -eq 0 ]; then
		printf ".";
		sleep 2;
	else
		loop_counter=`expr $max_count + 1`;
		printf ".";
		sleep 2;
		printf "\n"
	fi
done

echo =================== making all =========================
${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID} make_project ${SNIFFPROJNAME} all
echo ============ waiting on sniff making all ===============
sleep 5
printf ".";
loop_counter=1
max_count=1000
while test $loop_counter -le $max_count; do
	loop_counter=`expr $loop_counter + 1`
	if [ ${CURSYSTEM} == "Windows" ]; then
		grepret=`ps -ef | grep -v "grep" | grep -c "make$"`
	else
		grepret=`ps -ef | grep -v "grep" | grep -c "make.*all$"`
	fi
	if [ ! $grepret -eq 0 ]; then
		printf ".";
		sleep 2;
	else
		loop_counter=`expr $max_count + 1`;
		printf ".";
		sleep 2;
		printf "\n"
	fi
done

sleep 3
echo =============== terminating sniff ======================
${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID} close_project ${SNIFFPROJNAME}
${SNIFF_DIR}/bin/sniffaccess -s ${SNIFF_SESSION_ID} quit

cleanfiles;

exit 0
