#!/bin/ksh
#
# Daily Build script for cron batch - sends resultmails 

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -a <config>  : config which you want to switch to, multiple definitions allowed'
	echo ' -w <pattern> : pattern to automatically select working env for testing, ex. "Solaris.*opt.*wddbg"'
	echo ' -D           : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_wepatt="";
cfg_dbg=0;
# process command line options
while getopts ":a:w:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
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

tester_email="$1"

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	cfg_toks=$cfg_toks" -a "$cfgtok;
done
cfg_and="$cfg_toks";

SDIR=`dirname $0`
. ${SDIR}/envForTests.sh $cfg_opt

# remove wdtestmake files if older than 7 days
find ${BUILD_OUTPUT_DIR} -name "${LOGFILENAME}*" -ctime +7 -exec rm -f {} \;
find ${BUILD_OUTPUT_DIR} -name "${FAILUREFILENAME}*" -ctime +7 -exec rm -f {} \;
find ${BUILD_OUTPUT_DIR} -name "${RESULTFILENAME}*" -ctime +7 -exec rm -f {} \;

# use incrementalBuild script as full build (-f) and use cvs co (-u) to get latest files
$SCRIPTDIR/incrementalBuild.sh $cfg_opt -b -f -u $cfg_and $cfg_wepatt "$tester_email" > ${LOGFILE} 2>&1
retCode=$?;
mailHostPattern="DailyBuild on ["${HOSTNAME}"] ["${cfg_wepatt:-"-w "${WE_PATTERN}}"]";
if [ $retCode -eq 0 ]; then
	# there seems to be no errors of the tests but...
	if [ ! -e "$FAILURE_FILE" ]; then
		# ...nothing, everything is fine
		${DATE_EXEC} > ${DEV_HOME}/LastSuccessfulBuildTest.${HOSTNAME}
		# ... but still leave a trace of the successful tests
		mailSubject=$mailHostPattern": HOORAY, builds and tests OK";
		${MAIL_PRG} -s "${mailSubject}" $SENDER_EMAIL "$tester_email"  < ${RESULTFILE}
		case "${CURSYSTEM}" in
			SunOS)
#				$SCRIPTDIR/repositoryDeliveryForAtraxis $ATRAXIS_EMAIL_ADDRESS > ${ATRAXISLOGFILE} 2>&1
			;;
			Linux)
				$SCRIPTDIR/UpdateESF.sh
				#
				# deactivated for now ATT Tests as eSport/Eprise integrated testsystem doesnt run
				# with itopia/webdisplay properly right now - this depends on customer "eSport"!
				# Therefore ATT tests had plenty of failures since quite a while. - grr
				#
				#/home/wdtester/DAILYBUILD.Linux/WWW/eSportFoundation/FunkTest/DailyBuildRunScenarios.sh
			;;
		esac
	else
		# ...there was that shity failurefile...
		mailSubject=$mailHostPattern": OOOOPS, builds and tests failed";
		${MAIL_PRG} -s "${mailSubject}" $SENDER_EMAIL "$tester_email" < ${LOGFILE}
#		${MAIL_PRG} -s "${mailSubject}" $SENDER_EMAIL "$tester_email" $ATRAXIS_EMAIL_ADDRESS < ${LOGFILE}
	fi
else
	# there were regular errors
	mailSubject=$mailHostPattern": OOPS, builds and tests failed";
	${MAIL_PRG} -s "${mailSubject}" $SENDER_EMAIL "$tester_email" < ${LOGFILE}
#	${MAIL_PRG} -s "${mailSubject}" $SENDER_EMAIL "$tester_email" $ATRAXIS_EMAIL_ADDRESS < ${LOGFILE}
fi
