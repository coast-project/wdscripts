#!/bin/ksh
# 

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] [files|directories|modules]'
	echo 'where options are:'
	echo ' -f            : if defined, print full information'
	echo ' -n <name>     : filename of outputfile, default [version.txt]'
	echo ' -s <sep>      : separator of columns, default is space'
	echo ' -w <num>      : width of first column (filename) in characters, default is unformatted'
	echo ' -D            : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_opt="";
cfg_dbg=0;
cfg_awkopt="";
cfg_sep="";
cfg_width=0;
cfg_filename="version.txt";
# process command line options
while getopts ":fn:s:w:D" opt; do
	case $opt in
		f)
			cfg_awkopt="-v fullinfo=1";
		;;
		n)
			cfg_filename=${OPTARG};
		;;
		s)
			cfg_sep=${OPTARG};
		;;
		w)
			cfg_width=${OPTARG};
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

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

if [ -n "$cfg_sep" ]; then
	cfg_sep="-v sep="$cfg_sep;
fi
cfg_width="-v width="$cfg_width;
cfg_filename="-v outname="$cfg_filename;

if [ $cfg_dbg -eq 1 ]; then
	echo 'sep ['$cfg_sep']';
	echo 'width ['$cfg_width']';
	echo 'awkopt ['$cfg_awkopt']';
	echo 'filename ['$cfg_filename']';
fi

cvs status -v $* | awk $cfg_awkopt $cfg_sep $cfg_width $cfg_filename -f $mypath/getTagVersion.awk 
