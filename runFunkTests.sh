#!/bin/ksh

TestScript=RunFunkTests.sh

SDIR=`dirname $0`
. ${SDIR}/envForTests.sh

function runAllFunkTests
{
	MAILMSG=
	WDRetCode=0
	if [ -x ./$TestScript ]; then
		./$TestScript -all 2>${WDTEST_ERRFILE} >${WDTEST_OUTFILE} 
	fi
	RetCode=$?
	fname=`date "+$1%y%j"`
	if [ $RetCode -eq 0 ]; then
		echo $1 funktests successful
		if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
			echo $1 output file generated
			mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
			rm ${WDTEST_ERRFILE}	# clean up your mess
		else
			MAILMSG="No output from $1 funkttests"
		fi
	else
		if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
			echo $1 output file generated
			res=`${GREP_PRG} FAILURES ${WDTEST_OUTFILE}`
			if [ -n "$res" ]; then
				echo Failures in tests
				$MAIL_PRG -s "DailyBuild: Failures in daily $1 tests" $SENDER_EMAIL $2 <${WDTEST_OUTFILE}
				echo $1 ": " Failures >> $FAILURE_FILE
			fi
			cat ${WDTEST_ERRFILE} >> $FAILURE_FILE
			cat ${WDTEST_OUTFILE} >> $FAILURE_FILE
			mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
			rm ${WDTEST_ERRFILE}	# clean up your mess
		else
			MAILMSG="No output from $1 tests"
		fi
		MAILMSG="$1 tests exited with error code $RetCode check $FAILURE_FILE"
		echo $MAILMSG >> $FAILURE_FILE
		FAILED_DIRS=${FAILED_DIRS}$1,
	fi
	if [ -n "$MAILMSG" ]; then
		echo $MAILMSG
		( echo $MAILMSG ; env ) | $MAIL_PRG -s "DailyBuild: Result of $1 FunkTests" $SENDER_EMAIL $2
		echo $1 ": " $MAILMSG >> $FAILURE_FILE
		env >> $FAILURE_FILE
	fi
	return $RetCode
} # runAllFunkTests

buildFailed=0

if [ ! -d "${DEV_HOME}/archive" ]; then
	mkdir -p ${DEV_HOME}/archive
fi

for d in `find ${DEV_HOME}/WWW ${DEV_HOME}/testfw -name $TestScript -type f -print`
do
    echo $d
    msgfile=`echo $d | awk -F/ '{ field = NF-1; print $field }'`
	if [ "$msgfile" = "Test" ]; then
		msgfile=`echo $d | awk -F/ '{ field = NF-2; print $field }'`
		if [ "$msgfile" = "src" ]; then
	    	msgfile=`echo $d | awk -F/ '{ field = NF-3; print $field }'`
		fi ;
    fi
    export WD_ROOT=`dirname $d`
    export WD_PATH=.:config
    cd ${WD_ROOT} && runAllFunkTests $msgfile $1
    buildFailed=`expr  "$buildFailed" + "$?" `
done

if [ -z "${FAILED_DIRS}" ]; then
	echo "tests OK"
else
	echo failed dirs: $FAILED_DIRS
fi

exit $buildFailed
