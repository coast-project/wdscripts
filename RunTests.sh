#!/bin/ksh

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] -- TestName...'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -e          : enable error-logging to console, default no logging'
	echo ' -m <mailaddr> : mail address of test output receiver'
	echo ' -s          : enable error-logging into SysLog, eg. /var/[adm|log]/messages, default no logging into SysLog'
	echo ' -D          : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo 'where TestName is:'
	echo ' -all        : do all tests of this suite'
	echo ' -list       : list all existing tests'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_dbg=0;
cfg_mailaddr="";
cfg_errorlog=0;
cfg_syslog=0;
# process command line options
while getopts ":a:em:s-D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		e)
			cfg_errorlog=1;
		;;
		m)
			cfg_mailaddr="${OPTARG}";
		;;
		s)
			cfg_syslog=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
			cfg_dbg=1;
		;;
		-)
			break;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

cfg_testparams="$@";

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	if [ -n "${cfg_toks}" ]; then
		cfg_toks=${cfg_toks}" ";
	fi
	cfg_toks=$cfg_toks"-a "$cfgtok;
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

# include global configuration
. ${mypath}/config.sh $cfg_opt

# allow overriding of cfg_toks variable within common part of prjRunTest.sh
cfg_subscript=`pwd`/prjRunTest.sh;
if [ -f "${cfg_subscript}" ]; then
	echo ' ---- using ['${cfg_subscript}'] with param(s) ['$cfg_testparams']'
	echo ''
	. ${cfg_subscript}
fi

if [ -n "$cfg_toks" ]; then
	echo ''
	echo ' ---- configuring Test configurations with ['$cfg_toks']'
	echo ''
fi

# now prepare the test configuration, do not log changes to file
$mypath/setConfig.sh $cfg_opt $cfg_toks -l /dev/null

# enable logging if wanted
if [ $cfg_errorlog -eq 1 ]; then
	export WD_LOGONCERR=1;
fi
if [ $cfg_syslog -eq 1 ]; then
	export WD_DOLOG=1;
fi

# do the tests now
if [ -f "${cfg_subscript}" ]; then
	echo '  --- calling prepareTest'
	# this function MUST be defined in prjRunTest.sh
	prepareTest;

	echo '  --- calling callTest'
	# this function MUST be defined in prjRunTest.sh
	callTest;
	ret_code=$?;

	echo '  --- calling cleanupTest'
	# this function MUST be defined in prjRunTest.sh
	cleanupTest;
else
	echo ' ERROR: project specific RunTest script ['${cfg_subscript}'] not found, aborting!';
	ret_code=222;
fi

# this MUST be the last thing we do
exit $ret_code;
