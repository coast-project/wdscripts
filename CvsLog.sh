#!/bin/ksh
#

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] [files|directories|modules]'
	echo 'where options are:'
	echo ' -r <param>    : param which is used as -r param to cvs log'
	echo ' -s            : if defined, print a log summary'
	echo ' -T            : test only what cvs would output'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_opt="";
cfg_dbg=0;
cfg_filename="ChangeLog.txt";
cfg_logopt="";
cfg_bare="";
cfg_test=0;
# process command line options
while getopts ":sr:DT" opt; do
	case $opt in
		r)
			cfg_logopt="-r"${OPTARG};
		;;
		s)
			cfg_bare="-v bare=1";
		;;
		D)
			# propagating this option to config.sh
			cfg_opt="-D";
			cfg_dbg=1;
		;;
		T)
			cfg_test=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

if [ -z "$cfg_logopt" ]; then
	showhelp;
fi

if [ $cfg_test -eq 0 ]; then
	cvs log -N $cfg_logopt $*> gugus.txt 2>&1
	awk -f $mypath/filterLogFile.awk $cfg_bare -v revstr=$cfg_logopt gugus.txt
else
	cvs log -N $cfg_logopt $*
fi

if [ -e gugus.txt ]; then
	rm -f gugus.txt;
fi
