#!/bin/ksh
#
# script to add dll make support to a project
#

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] <filespec>'
	echo 'where options are:'
	echo ' -c <cfgname> : override config filename, default is ['$cfg_filename']'
	echo ' -p <prjname> : override project name, default ['$PROJECTNAME']'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ' -T : test mode, if defined nothing will be done but printed on console'
	echo 'where filespec is:'
	echo ' <filespec>   : single files or "*.h", "*.cpp" and so on, use quoting!'
	echo ''
	exit 4;
}

cfg_opt="";
cfg_dbg=0;
cfg_prjname="";
cfg_test=0;
cfg_filename="";
# process command line options
while getopts ":c:p:DT" opt; do
	case $opt in
		c)
			cfg_filename=${OPTARG};
		;;
		p)
			cfg_prjname=${OPTARG};
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

# load global config
. $mypath/config.sh $cfg_opt

if [ -z "$cfg_prjname" ]; then
	# use default
	cfg_prjname=$PROJECTNAME;
fi

if [ -z "$cfg_filename" ]; then
	# use default
	cfg_filename=config_$cfg_prjname;
fi

set -f;
while [ -n "$1" ]; do
	if [ $cfg_dbg -eq 1 ]; then echo 'filespec is ['$1']'; fi
	cfg_filespec=$cfg_filespec" "$1;
	shift
done
set +f;

if [ $cfg_dbg -eq 1 ]; then
	echo 'Projectname      ['$cfg_prjname']'
	echo 'Configfilename   ['$cfg_filename']'
	set -f;
	echo 'filespec         ['$cfg_filespec']'
	set +f;
fi

awkclassname=$mypath/dllsup_class.awk
cat $awkclassname > __foo_tmp.awk

AWK_PRG=awk

if [ $cfg_test -eq 1 ]; then
	echo 'Testing in ['$cfg_prjname']...'
	for fname in $cfg_filespec; do
		if [ $cfg_dbg -eq 1 -o $cfg_test -eq 1 ]; then echo ' processing ['$fname']'; fi
		$AWK_PRG -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -v showonly=1 -v testmodify=0 -f __foo_tmp.awk "$fname"
	done
else
	# adjust files retrieved with given filespec
	for fname in $cfg_filespec; do
		if [ $cfg_dbg -eq 1 -o $cfg_test -eq 1 ]; then echo ' processing ['$fname']'; fi
		$AWK_PRG -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -v showonly=1 -v testmodify=1 -f __foo_tmp.awk "$fname"
		if [ $? -eq 0 ]; then
			echo '  changing ['$fname']';
			mv "$fname" "$fname.bak";
			$AWK_PRG -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -f __foo_tmp.awk "$fname.bak"
		fi
	done
	# create config header file if not already existing
	if [ ! -f "$cfg_filename.h" ]; then
		$AWK_PRG -v pname="$cfg_prjname" '{ pnameup=toupper(pname); gsub("TMPL",pnameup); print}' $mypath/dllsup_.h > $cfg_filename.h
	fi
	# create config source file if not already existing
	if [ ! -f "$cfg_filename.cpp" ]; then
		$AWK_PRG -v pname="$cfg_prjname" '{ pnameup=toupper(pname); gsub("TMPL",pnameup); gsub("tmpl",pname); print}' $mypath/dllsup_.cpp > $cfg_filename.cpp
	fi
fi

rm -f __foo_tmp.awk
