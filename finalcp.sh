#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# cp installation files into corresponding CD directory
#
############################################################################

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [ options]'
	echo 'where options are:'
	echo ' -a <name>: config which must be defined, multiple definitions allowed'
	echo ' -n <name>: name of the project which will be used to create the package tar name, default is ['${TARGZNAME%.*}']'
	echo ' -t <dir> : directory where distribution files reside'
	echo ' -c <dir> : directory to put files into'
	echo ' -v <ver> : suffix for directory name when creating distribution package, appended to config-name (-a param)'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_tmpdir="";
cfg_and="";
cfg_cddir="";
cfg_suffix="";
cfg_dirname="";
cfg_name="";
cfg_dbg=0;
# process command line options
while getopts ":a:n:t:c:v:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}"_";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		n)
			cfg_name="${OPTARG}";
		;;
		t)
			cfg_tmpdir="${OPTARG}";
		;;
		c)
			cfg_cddir="${OPTARG}";
		;;
		v)
			cfg_suffix="${OPTARG}";
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

if [ -z "$cfg_and" ]; then
	echo 'ERROR: you have to specify at least one configuration, exiting !'
	showhelp;
fi
if [ -z "$cfg_tmpdir" ]; then
	echo 'ERROR: you have to specify the directory with the compressed distribution files, exiting !'
	showhelp;
fi
if [ -z "$cfg_cddir" ]; then
	echo 'ERROR: you have to specify the destination directory, exiting !'
	showhelp;
fi
if [ -z "$cfg_name" ]; then
	cfg_name="${TARGZNAME%.*}";
fi

cfg_dirname=${cfg_and}${cfg_suffix};

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - '$PRJ_DESCRIPTION
echo ''

INSTALLDIR=$cfg_cddir/${cfg_dirname}

mkdir -p $INSTALLDIR 2>/dev/null
if [ $? -ne 0 ]; then
	echo 'ERROR: failed to create destination directory ['$INSTALLDIR'], exiting !'
	exit
fi

echo 'Install dir: ['$INSTALLDIR']'
echo 'Archive:     ['$TARGZNAME']'
echo ''

# cp utilities scripts and tar to final cd directory
# use platform correct gunzip binary
case "${CURSYSTEM}" in
	SunOS)
		GUNZIPBIN=gunzip.bin.SunOS
	;;
	Linux)
		GUNZIPBIN=gunzip.bin.Linux
	;;
	unknown)
		GUNZIPBIN=gunzip.bin.SunOS
	;;
esac

echo '  --- copying  ['$GUNZIPBIN'] to ['$INSTALLDIR'/'${GUNZIPBIN%.*}']'
cp $SCRIPTDIR/$GUNZIPBIN $INSTALLDIR/${GUNZIPBIN%.*} 2>/dev/null

for cpfilname in $SCRIPTDIR/install.sh $SCRIPTDIR/sysfuncs.sh $SCRIPTDIR/config.sh $CONFIGDIRABS/prjconfig.sh $CONFIGDIRABS/prjinstall.sh $cfg_tmpdir/$TARGZNAME; do
	if [ -f "$cpfilname" ]; then
		printf "  --- %-8s [%s] ... " "copying" "$cpfilname"
		cp $cpfilname $INSTALLDIR 2>/dev/null
		if [ $? -eq 0 ]; then
			printf "done\n"
		else
			printf "failed\n"
		fi
	fi
done

rm -f $cfg_tmpdir/$TARGZNAME 2>/dev/null

# creating final tar file for delivery
( cd $INSTALLDIR && tar cf ${cfg_name}_${cfg_suffix}.tar * )

echo ''
echo '------------------------------------------------------------------------'
echo ''
