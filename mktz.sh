#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# generate final tar.gz file
#
############################################################################

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [ options]'
	echo 'where options are:'
	echo ' -t <dir>  : directory which will be tar-gzipped'
	echo ' -s <size> : split the archive into multiple part of size-kb'
	echo ' -n <name> : name of the archive which will be created in ['$cfg_tmpdir'], default is ['${TARGZNAME}']'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_tmpdir="";
cfg_size=1423;
cfg_dosplit=0;
cfg_name="";
cfg_dbg=0;
# process command line options
while getopts ":t:s:n:D" opt; do
	case $opt in
		t)
			cfg_tmpdir="${OPTARG}";
		;;
		s)
			cfg_size=${OPTARG};
			cfg_dosplit=1;
		;;
		n)
			cfg_name="${OPTARG}";
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

# load global config
. $mypath/config.sh $cfg_opt

if [ -z "$cfg_tmpdir" ]; then
	echo 'ERROR: you have to specify the directory to be compressed, exiting !'
	showhelp;
fi
if [ -z "$cfg_name" ]; then
	cfg_name="${TARGZNAME}";
fi
if [ -z "$cfg_name" ]; then
	echo 'ERROR: no valid archive name given, exiting!'
	showhelp;
fi

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - '$PRJ_DESCRIPTION
echo ''

echo ' ---- Creating archive'
for addedfile in `cd $cfg_tmpdir; tar cvfz $cfg_name --exclude "$LOGDIR/*.log" --exclude "$LOGDIR/*.PID" *`; do
	echo '  --- added  ['$addedfile']'
done

printf " ---- Testing contents of [%s] ... " "$cfg_name"
tar tfz $cfg_tmpdir/$cfg_name >/dev/null
if [ $? -eq 0 ]; then
	printf "OK\n"
else
	printf "FAILED\n"
fi

if [ $cfg_dosplit -eq 1 ]; then
	echo ' ---- Splitting file'
	( cd $cfg_tmpdir; split -b ${cfg_size}k $cfg_name );
fi

echo ''
echo '------------------------------------------------------------------------'
echo ''
