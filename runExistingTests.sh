#!/bin/ksh

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -a <config>   : config which you want to switch to, multiple definitions allowed'
	echo ' -m <mailaddr> : mail address of test output receiver'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_dbg=0;
cfg_mailaddr="";
# process command line options
while getopts ":a:m:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		m)
			cfg_mailaddr="${OPTARG}";
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

if [ -z "$cfg_mailaddr" ]; then
	echo ' ERROR: mail address not given, aborting!'
	showhelp;
fi

cfg_testparams="$@";

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	cfg_toks=$cfg_toks" -a "$cfgtok;
done
cfg_and="$cfg_toks";

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

prjTestScript=prjRunTest.sh
globalTestScript="${mypath}/RunTests.sh"
globalTestScriptOpts="-m "$cfg_mailaddr" $cfg_and $cfg_opt -- -all"
testExecutable=./wdtest${EXEEXT}
testExecutableOpts="-all"

. ${mypath}/envForTests.sh $cfg_opt

mailHostPattern=${mailHostPattern:-"DailyBuild on ["${HOSTNAME}"]"};

function runTests
{
	local l_prjUnderTest=$1;
	MAILMSG=
	RetCode=0
	LIBNAME=`ls lib*${DLLEXT} 2>/dev/null`
	if [ -x ${testExecutable} -o -x ./$LIBNAME ]; then
		echo ${l_prjUnderTest}' test executable found in '`pwd` | tee -a ${RESULTFILE};
		if [ -f "${prjTestScript}" -a -x "${globalTestScript}" ]; then
			echo ' doing tests with ['${globalTestScript}']' | tee -a ${RESULTFILE};
			${globalTestScript} ${globalTestScriptOpts} 2>${WDTEST_ERRFILE} >${WDTEST_OUTFILE}
		else
			echo ' doing tests with ['${testExecutable}']' | tee -a ${RESULTFILE};
			${testExecutable} ${testExecutableOpts} 2>${WDTEST_ERRFILE} >${WDTEST_OUTFILE}
		fi
		RetCode=$?;
		fname=`date "+${l_prjUnderTest}%y%j"`
		if [ $RetCode -eq 0 ]; then
			if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
				local teststats=`cat ${WDTEST_OUTFILE} | grep "assertions run.*failures.*complete"`;
				if [ -n "$teststats" ]; then
					echo '  '$teststats | tee -a ${RESULTFILE};
				else
					echo '  '${l_prjUnderTest}' output file generated' | tee -a ${RESULTFILE};
				fi;
				mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
				rm ${WDTEST_ERRFILE}	# clean up your mess
			else
				MAILMSG="No output from [${l_prjUnderTest}] tests"
				echo '  '${MAILMSG} | tee -a ${RESULTFILE};
			fi
			if [ -n "$SUCCESSFUL_DIRS" ]; then
				SUCCESSFUL_DIRS=$SUCCESSFUL_DIRS",";
			fi
			SUCCESSFUL_DIRS=$SUCCESSFUL_DIRS${l_prjUnderTest}
		else
			MAILMSG="${l_prjUnderTest} tests exited with error code $RetCode check $FAILURE_FILE"
			echo $MAILMSG >> $FAILURE_FILE
			echo '--- content of errorfile ---' >> $FAILURE_FILE
			cat ${WDTEST_ERRFILE} >> $FAILURE_FILE
			echo '--- content of outputfile ---' >> $FAILURE_FILE
			cat ${WDTEST_OUTFILE} >> $FAILURE_FILE
			if [ -n "$FAILED_DIRS" ]; then
				FAILED_DIRS=$FAILED_DIRS",";
			fi
			FAILED_DIRS=$FAILED_DIRS${l_prjUnderTest};

			if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
				echo '  '${l_prjUnderTest}' output file generated'
				res=`${GREP_PRG} FAILURES ${WDTEST_OUTFILE}`
				if [ -n "$res" ]; then
					( echo $MAILMSG ; echo; echo "==== environment ===="; echo; env | sort; echo; echo "==== test output ===="; echo; cat ${WDTEST_OUTFILE} ) | $MAIL_PRG ${SENDER_EMAIL} -s "${mailHostPattern}: Result of [${l_prjUnderTest}] tests" ${cfg_mailaddr}
					# do not send another message, eg reset MAILMSG
					MAILMSG="";
					echo ${l_prjUnderTest} ": " Failures >> $FAILURE_FILE
				fi
				mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
				rm ${WDTEST_ERRFILE}	# clean up your mess
			else
				MAILMSG="No output from [${l_prjUnderTest}] tests"
			fi
		fi
	else
		MAILMSG="Build of [${l_prjUnderTest}] failed"
		RetCode=1;
		if [ -n "$FAILED_DIRS" ]; then
			FAILED_DIRS=$FAILED_DIRS",";
		fi
		FAILED_DIRS=${FAILED_DIRS}${l_prjUnderTest};
	fi
	if [ -n "$MAILMSG" ]; then
		echo ' '$MAILMSG
		( echo $MAILMSG ; echo; echo "==== environment ===="; echo; env | sort ) | $MAIL_PRG ${SENDER_EMAIL} -s "${mailHostPattern}: Result of [${l_prjUnderTest}] tests" ${cfg_mailaddr}
		echo ${l_prjUnderTest} ": " $MAILMSG >> $FAILURE_FILE
		env >> $FAILURE_FILE
	fi
	return $RetCode
}

buildFailed=0

if [ ! -d "${DEV_HOME}/archive" ]; then
	mkdir -p ${DEV_HOME}/archive
fi

echo >${RESULTFILE}
echo 'Summary of Tests:' | tee -a ${RESULTFILE}

for d in `find ${DEV_HOME}/WWW ${DEV_HOME}/testfw -name ${prjTestScript} -type f -print`; do
	echo | tee -a ${RESULTFILE};
    prjUnderTest=`echo $d | awk -F/ '{ field = NF-1; print $field }'`
	if [ "$prjUnderTest" = "Test" ]; then
		prjUnderTest=`echo $d | awk -F/ '{ field = NF-2; print $field }'`
		if [ "$prjUnderTest" = "src" ]; then
	    	prjUnderTest=`echo $d | awk -F/ '{ field = NF-3; print $field }'`
		fi;
    fi;
    # delete files older than 7 days in archive directory
    find ${DEV_HOME}/archive -name "${prjUnderTest}*" -ctime +7 -exec rm -f {} \;
    unset WD_ROOT; unset WD_PATH;
    cd `dirname $d` && runTests $prjUnderTest
    buildFailed=`expr  "$buildFailed" + "$?" `
done

echo | tee -a ${RESULTFILE};
echo 'successful tests: '$SUCCESSFUL_DIRS | tee -a ${RESULTFILE};
echo | tee -a ${RESULTFILE};
if [ -z "${FAILED_DIRS}" ]; then
	echo 'all tests OK' | tee -a ${RESULTFILE};
else
	echo 'failed tests:     '$FAILED_DIRS | tee -a ${RESULTFILE};
fi

exit $buildFailed
