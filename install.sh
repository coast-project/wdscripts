#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# install the current distribution and optionally link the directory
#
############################################################################

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -p <directory> : directories in which files will be copied'
	echo ' -l <linkname>  : name of symbolic link which will be created one level below the given target directory to it'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_path="";
cfg_link="";
cfg_dbg=0;
# process command line options
while getopts ":p:l:D" opt; do
	case $opt in
		p)
			# copy path and delete trailing slash if any
			cfg_path=${OPTARG%/};
		;;
		l)
			cfg_link=${OPTARG};
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

if [ -z "$cfg_path" ]; then
	echo
	echo 'ERROR: destination directory must be specified, exiting!'
	showhelp;
fi;
cfg_relpath=${cfg_path##*/}
cfg_pathparent=${cfg_path%/*}
if [ -d "$cfg_path" ]; then
	echo
	echo 'ERROR: destination path already exists, exiting!'
	echo 'content of destination directory parent ['$cfg_pathparent']:'
	ls -la $cfg_pathparent;
	exit 4;
fi
GUNZIP="./gunzip.bin";
if [ ! -f "$GUNZIP" -a ! -x "$GUNZIP" ]; then
	echo
	echo 'ERROR: ['$GUNZIP'] binary can not be found or is not executable, exiting!'
	exit 4;
fi;
if [ ! -f "$TARGZNAME" ]; then
	echo
	echo 'ERROR: install package ['$TARGZNAME'] does not exist, exiting!'
	exit 4;
fi

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - installing project ['$PROJECTNAME']'
echo ''

echo ' ---- Unpacking contents of package ['$TARGZNAME'] into path ['$cfg_path']'

printf "  --- creating directory [%s] ... " $cfg_path
mkdir -p $cfg_path 2>/dev/null
if [ $? -ne 0 ]; then
	printf "failed\n"
	exit 1
else
	printf "done\n"
fi

printf "  --- copying    [%s] to [%s] ... " $TARGZNAME $cfg_path
cp ./$TARGZNAME $cfg_path 2>/dev/null
if [ $? -ne 0 ]; then
	printf "failed\n"
	exit 1
else
	printf "done\n"
fi

printf "  --- unzipping  [%s] in [%s] ... " $TARGZNAME $cfg_path
$GUNZIP $cfg_path/$TARGZNAME
if [ $? -ne 0 ]; then
	printf "failed\n"
	exit 1
else
	TARGZNAME=${TARGZNAME%%.tgz}.tar
	printf "done\n"
fi

printf "  --- extracting [%s] ... " $TARGZNAME
( cd $cfg_path && tar xf $TARGZNAME )
if [ $? -ne 0 ]; then
	printf "failed\n"
	exit 1
else
	printf "done\n"
fi

(cd $cfg_path && rm -f $TARGZNAME 2>/dev/null )

###########################################################################
# do project specific installing
if [ ! -f $mypath/prjinstall.sh ]; then
	echo
	echo 'WARNING: project specific install file ['$mypath'/prjinstall.sh] not found'
	echo 'installing only generic parts'
fi

if [ -f $mypath/prjinstall.sh ]; then
	. $mypath/prjinstall.sh
fi

###########################################################################
# generic again
# check if we have to link a directory
cd $cfg_path
if [ ! -z "${cfg_link}" ]; then
	cd $cfg_pathparent
	echo '  --- now in     ['`pwd`']'
	if [ -L "${cfg_link}" ]; then
		echo "   -- removing existing link"
		rm -f ${cfg_link}
	fi;
	echo '  --- creating symbolic link ['$cfg_link'] to ['$cfg_relpath']'
	ln -s ${cfg_relpath} ${cfg_link} 2>/dev/null
fi

echo ''
echo 'package successfully installed into ['$cfg_path']'
echo '------------------------------------------------------------------------'
echo ''
