#!/bin/ksh

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] mail-address'
	echo 'where options are:'
	echo ' -a <config>  : config which you want to switch to, multiple definitions allowed'
	echo ' -b           : do batch mode build, no helping messages'
	echo ' -f           : full build (default incremental), remove everything, checkout and build'
	echo ' -u           : do checkout/update before build'
	echo ' -w <pattern> : pattern to automatically select working env for testing, ex. "Solaris.*opt.*wddbg"'
	echo ' -D           : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_fullbuild=0;
cfg_docheckout=0;
cfg_dbg=0;
# process command line options
while getopts ":a:bfDuw:" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		b)
			cfg_batch="-b";
		;;
		f)
			cfg_fullbuild=1;
		;;
		u)
			cfg_docheckout=1;
		;;
		w)
			cfg_wepatt="-w "${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
			cfg_dbg=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

if [ -n "$1" ]; then
	cfg_mailaddr="$1"
else
	echo ''
	echo 'NO MAIL-ADDRESS given as param, ABORTING!'
	showhelp;
fi

DNAM=`dirname $0`
if [ "${DNAM}" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

#Setup environment
. ${mypath}/envForTests.sh $cfg_opt

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	cfg_toks=$cfg_toks" -a "$cfgtok;
done
cfg_and="$cfg_toks";

# only set cfg_wepatt to WE_PATTERN if it is not given, WE_PATTERN is only set for wdtester
if [ -z "$cfg_wepatt" -a -n "${WE_PATTERN}" ]; then
	cfg_wepatt="-w "${WE_PATTERN};
	echo 'we-pattern-cfg ['${cfg_wepatt}']';
fi

# print a summary of what the script is doing
if [ "$cfg_batch" = "-b" ]; then
	echo '- doing batch mode build';
fi
if [ $cfg_docheckout -eq 1 ]; then
	echo '- doing cvs co for directories';
fi
if [ $cfg_fullbuild -eq 1 ]; then
	echo '- doing full build';
fi
if [ -n "$cfg_wepatt" ]; then
	echo '- we-pattern is ['$cfg_wepatt']';
fi
echo '- mail-address is ['$cfg_mailaddr']'
echo ''
echo 'using '$SHELL' to run exectest, I am '${USER}', now in ['$PWD'], LD_LIBRARY_PATH : ['$LD_LIBRARY_PATH']'
echo ''

if [ -e ${LOCK_FILE} ]; then
	# if the lock file is present someone is already running a build
	# BUT if the file is older than say 4 hours (240 minutes) delete the lockfile and start build
	# if the return of find is the empty string the lockfile was not older than we expected so exit
	nRET=`find ${LOCK_FILE} -cmin +240 -exec rm -f {} \; -print`
	if [ -z "$nRET" ]; then
		echo "Build is already at work: $LOCK_FILE exists and contains:"
		cat $LOCK_FILE;
		exit 4
	else
		echo 'BROKE LOCK and running build now'
	fi
fi

Result=1;
echo "given email: $cfg_mailaddr" > ${LOCK_FILE}
echo "user name  : $LOGNAME" >> ${LOCK_FILE}
echo "started    : ${TIME_STAMP}" >> ${LOCK_FILE}

function exitproc
{
	rm -f ${LOCK_FILE}
	exit ${Result};
}

trap exitproc INT
trap exitproc HUP
trap exitproc TERM
trap exitproc KILL

#remove old builds when we are running a full build
cleanopt="clean_targets"
if [ ${cfg_fullbuild} -eq 1 ] ; then
	echo "============== Fullbuild: moving old build"
	rm -rf ${DEV_HOME}/testfw.old
	mv ${DEV_HOME}/testfw ${DEV_HOME}/testfw.old 
	rm -rf ${DEV_HOME}/WWW.old
	mv ${DEV_HOME}/WWW ${DEV_HOME}/WWW.old
	#/home/scripts/bin/MakeNewProject.sh TestStdProject MySQLBasedStandard
	cleanopt="clean clean_targets";
fi

# remove libs in WD_LIBDIR only if we can cd to the dir
echo '============== removing libs in WD_LIBDIR ['${WD_LIBDIR}']'
cd ${WD_LIBDIR} && rm -f *.so

if [ ! -d "${DEV_HOME}" ]; then
	mkdir -p ${DEV_HOME}
fi

#Check out Projects if necessary
if [ ${cfg_docheckout} -eq 1 ]; then
	cd ${DEV_HOME}
	for modulename in ${DO_CHECKOUT}; do
		echo "============== checking out/updating project ["${modulename}"]"
		cvs co -P ${modulename}
	done
fi

# do the cleaning now, eg. make clean_targets and clean
for prjdir in ${DO_PROJECTS}; do
	cd ${DEV_HOME}/${prjdir}
	${SCRIPTDIR}/BuildProject.sh $cfg_opt $cfg_batch -l -m "$cleanopt" ${cfg_wepatt} $cfg_opt
done

# do the compilation now, eg. make clean_targets and all
for prjdir in ${DO_PROJECTS}; do
	cd ${DEV_HOME}/${prjdir}
	${SCRIPTDIR}/BuildProject.sh $cfg_opt $cfg_batch -l -n -m "all" ${cfg_wepatt} $cfg_opt
done

#Runtests
export mailHostPattern="DailyBuild on ["${HOSTNAME}"] ["${cfg_wepatt:-${WE_PATTERN}}"]";
echo '============== running Tests now'
${SCRIPTDIR}/runExistingTests.sh $cfg_opt $cfg_and -m "$cfg_mailaddr"

Result=$?

exitproc
