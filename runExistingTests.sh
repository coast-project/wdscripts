#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------

MYNAME=`basename $0`

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

# source in config switching helper
. $mypath/_cfgSwitch.sh

showhelp()
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	PrintSwitchHelp
	PrintSubSwitchHelp
	echo ' -m <mailaddr>      : mail address of test output receiver, multiple definitions allowed'
	echo ' -p <prjpath>       : path (rel or abs) in which to recursively look for test scripts, multiple definitions allowed'
	echo ' -D                 : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_prjs="";
cfg_dbg=0;
cfg_mailaddr="";

# process config switching options first
myPrgOptions=":m:p:D"
ProcessSetConfigOptions "${myPrgOptions}" "$@"
OPTIND=1;

# process other command line options
while getopts "${myPrgOptions}${cfg_setCfgOptions}" opt; do
	case $opt in
		m)
			if [ -n "$cfg_mailaddr" ]; then
				cfg_mailaddr=${cfg_mailaddr}" ";
			fi
			cfg_mailaddr=${cfg_mailaddr}${OPTARG};
		;;
		p)
			if [ -n "$cfg_prjs" ]; then
				cfg_prjs=${cfg_prjs}" ";
			fi
			cfg_prjs=${cfg_prjs}${OPTARG};
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
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

# prepare config switching tokens
PrepareTokensForCommandline

# prepare mail adresses, need to add -m before each addr
cfg_mailaddrs="";
for cfgtok in $cfg_mailaddr; do
	if [ $cfg_dbg -eq 1 ]; then echo 'addr is ['$cfgtok']'; fi
	cfg_mailaddrs=$cfg_mailaddrs" -m "$cfgtok;
done

prjTestScript=prjRunTest.sh
globalTestScript="${mypath}/RunTests.sh"
globalTestScriptOpts=" "$cfg_mailaddrs" $cfg_toks $cfg_dbgopt -- -all"
RunTestCmd=${globalTestScript}" "${globalTestScriptOpts}' 2>${WDTEST_ERRFILE} >${WDTEST_OUTFILE}';
firstErrorEntry=1;

. ${mypath}/envForTests.sh $cfg_dbgopt

mailHostPattern=${mailHostPattern:-"DailyBuild on ["${HOSTNAME}"]"};
ErrorEntryHeader="<html><title>${mailHostPattern}</title><body><h1>${TIME_STAMP}</h1>";
ErrorEntryFooter="</body></html>";

runTests()
{
	_prjUnderTest=$1;
	MAILMSG=
	RetCode=0;
	echo `${DATE_EXEC} "+%Y%m%d%H%M%S"`': '${_prjUnderTest}' Test starting' | tee -a ${RESULTFILE};
	if [ -f "${prjTestScript}" -a -x "${globalTestScript}" ]; then
		${globalTestScript} -c;
		if [ $? -eq 1 ]; then
			echo ${_prjUnderTest}' test executable found in '`pwd` | tee -a ${RESULTFILE};
			echo ' doing tests using ['${globalTestScript}']' | tee -a ${RESULTFILE};
			eval $RunTestCmd;
			RetCode=$?;
			fname=`${DATE_EXEC} "+${_prjUnderTest}%y%j"`
			_teststats="";
			if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
				_teststats=`cat ${WDTEST_OUTFILE} | grep "assertions run.*failures.*complete"`;
				if [ ! -n "$_teststats" ]; then
					_teststats=${_prjUnderTest}' output file generated';
				fi;
			else
				_teststats='No output from '${_prjUnderTest}' tests';
			fi;
			echo '  '$_teststats | tee -a ${RESULTFILE};
			if [ $RetCode -eq 0 ]; then
				if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
					mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
					rm ${WDTEST_ERRFILE}	# clean up your mess
				else
					MAILMSG="No output from [${_prjUnderTest}] tests"
				fi
				if [ -n "$SUCCESSFUL_DIRS" ]; then
					SUCCESSFUL_DIRS=$SUCCESSFUL_DIRS",";
				fi
				SUCCESSFUL_DIRS=$SUCCESSFUL_DIRS${_prjUnderTest}
			else
				MAILMSG="${_prjUnderTest} tests exited with error code $RetCode check $HTTP_FAILUREFILE#${_prjUnderTest}"
				if [ ${firstErrorEntry} -eq 1 ]; then
					firstErrorEntry=0;
					echo $ErrorEntryHeader >> $FAILURE_FILE;
				fi;
				echo "<a name=\"${_prjUnderTest}\"><h2>${_prjUnderTest} Tests</h2></a>" >> $FAILURE_FILE
				echo "<a href=\"#${_prjUnderTest}errors\">content of errorfile</a>" >> $FAILURE_FILE
				echo "<a href=\"#${_prjUnderTest}output\">content of outputfile</a>" >> $FAILURE_FILE
				echo "<pre>" >> $FAILURE_FILE
				echo $MAILMSG >> $FAILURE_FILE
				echo "<a name=\"${_prjUnderTest}errors\"><h3>--- content of errorfile ---</h3></a>" >> $FAILURE_FILE
				cat ${WDTEST_ERRFILE} >> $FAILURE_FILE
				echo "<a name=\"${_prjUnderTest}output\"><h3>--- content of outputfile ---</h3></a>" >> $FAILURE_FILE
				cat ${WDTEST_OUTFILE} >> $FAILURE_FILE
				echo "</pre>" >> $FAILURE_FILE
				if [ -n "$FAILED_DIRS" ]; then
					FAILED_DIRS=$FAILED_DIRS",";
				fi
				FAILED_DIRS=$FAILED_DIRS${_prjUnderTest};

				if [ -n "`cat ${WDTEST_OUTFILE}`" ]; then
					echo '  '${_prjUnderTest}' output file generated'
					res=`${GREP_PRG} FAILURES ${WDTEST_OUTFILE}`
					if [ -n "$res" ]; then
						( echo $MAILMSG ; echo; echo "==== environment ===="; echo; env; echo; echo "==== test output ===="; echo; cat ${WDTEST_OUTFILE} ) | $MAIL_PRG ${SENDER_EMAIL} -s "${mailHostPattern}: Result of [${_prjUnderTest}] tests" ${cfg_mailaddr}
						# do not send another message, eg reset MAILMSG
						MAILMSG="";
					fi
					mv ${WDTEST_OUTFILE} ${DEV_HOME}/archive/$fname
					rm ${WDTEST_ERRFILE}	# clean up your mess
				else
					MAILMSG="No output from [${_prjUnderTest}] tests"
				fi
			fi
		else
			MAILMSG="Build of [${_prjUnderTest}] failed"
			RetCode=1;
			if [ -n "$FAILED_DIRS" ]; then
				FAILED_DIRS=$FAILED_DIRS",";
			fi
			FAILED_DIRS=${FAILED_DIRS}${_prjUnderTest};
		fi
	else
		# check which needed file was not present
		if [ -f "${prjTestScript}" ]; then
			MAILMSG="Project specific [${prjTestScript}] of [${_prjUnderTest}] not present, aborting!";
		elif [ -x "${globalTestScript}" ]; then
			MAILMSG="Global [${globalTestScript}] not present or not executable, aborting!";
		fi;
		RetCode=1;
		if [ -n "$FAILED_DIRS" ]; then
			FAILED_DIRS=$FAILED_DIRS",";
		fi
		FAILED_DIRS=${FAILED_DIRS}${_prjUnderTest};
	fi
	if [ -n "$MAILMSG" ]; then
		echo ' '$MAILMSG
		( echo $MAILMSG ; echo; echo "==== environment ===="; echo; env ) | $MAIL_PRG ${SENDER_EMAIL} -s "${mailHostPattern}: Result of [${_prjUnderTest}] tests" ${cfg_mailaddr}
		if [ ${firstErrorEntry} -eq 1 ]; then
			firstErrorEntry=0;
			echo $ErrorEntryHeader >> $FAILURE_FILE;
		fi;
		echo "<a name=\"${_prjUnderTest}\"><h2>${_prjUnderTest} Tests</h2></a><pre>" >> $FAILURE_FILE
		( echo ${_prjUnderTest} ": " $MAILMSG ; echo; echo "==== environment ===="; echo; env ) >> $FAILURE_FILE
		echo "</pre>" >> $FAILURE_FILE
	fi
	return $RetCode
}

buildFailed=0

if [ ! -d "${DEV_HOME}/archive" ]; then
	mkdir -p ${DEV_HOME}/archive
fi

echo >${RESULTFILE}
echo 'Summary of '${mailHostPattern}':' | tee -a ${RESULTFILE}

for d in `${FINDEXE} ${cfg_prjs} -name ${prjTestScript} -type f -print | sort | uniq`; do
	echo | tee -a ${RESULTFILE};
    prjUnderTest=`echo $d | ${AWKEXE} -F/ '{ field = NF-1; print $field }'`
	if [ "$prjUnderTest" = "Test" ]; then
		prjUnderTest=`echo $d | ${AWKEXE} -F/ '{ field = NF-2; print $field }'`
		if [ "$prjUnderTest" = "src" ]; then
	    	prjUnderTest=`echo $d | ${AWKEXE} -F/ '{ field = NF-3; print $field }'`
		fi;
    fi;
    # delete files older than 7 days in archive directory
    ${FINDEXE} ${DEV_HOME}/archive -name "${prjUnderTest}*" -ctime +7 -exec rm -f {} \;
    unset WD_ROOT; unset WD_PATH;
    curpath=$PWD;
	if [ $cfg_dbg -eq 1 ]; then
		echo 'I am in ['`dirname $d`'] and execute tests of ['$prjUnderTest']';
	fi;
    cd `dirname $d` && runTests $prjUnderTest;
    buildFailed=`expr  "$buildFailed" + "$?" `;
    cd $curpath;
done

echo | tee -a ${RESULTFILE};
echo 'successful tests: '$SUCCESSFUL_DIRS | tee -a ${RESULTFILE};
echo | tee -a ${RESULTFILE};
if [ -z "${FAILED_DIRS}" ]; then
	echo 'all tests OK' | tee -a ${RESULTFILE};
else
	echo 'failed tests:     '$FAILED_DIRS | tee -a ${RESULTFILE};
fi
if [ ${firstErrorEntry} -eq 0 ]; then
	echo $ErrorEntryFooter >> $FAILURE_FILE;
fi;

exit $buildFailed
