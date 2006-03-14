#!/bin/ksh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# script to add dll make support to a project
#

MYNAME=`basename $0`

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
	# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

showhelp()
{
	echo ''
	echo 'usage: '$MYNAME' [options] <filespec>'
	echo 'where options are:'
	echo ' -c <cfgname> : override config filename, default is ['$cfg_filename']'
	echo ' -p <prjname> : override project name, default ['$PROJECTNAME']'
	echo ' -l           : convert prjname to lowercase, default keep case'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ' -T : test mode, if defined nothing will be done but printed on console'
	echo 'where filespec is:'
	echo ' <filespec>   : single files or "*.h", "*.cpp" and so on, use quoting!'
	echo ''
	exit 4;
}

cfg_dbgopt="";
cfg_dbg=0;
cfg_prjname="";
cfg_test=0;
cfg_filename="";
cfg_dolower=0;
# process command line options
while getopts ":c:lp:DT" opt; do
	case $opt in
		c)
			cfg_filename=${OPTARG};
		;;
		p)
			cfg_prjname=${OPTARG};
		;;
		l)
			cfg_dolower=1;
		;;
		D)
			# propagating this option to config.sh
			cfg_dbgopt="-D";
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

if [ $cfg_dbg -eq 1 ]; then echo 'params are ['"$@"']'; fi
cfg_params="$@";

# load global config
. $mypath/config.sh $cfg_dbgopt

if [ -z "$cfg_prjname" ]; then
	# use default
	cfg_prjname=$PROJECTNAME;
fi

if [ $cfg_dolower -eq 1 ]; then
	cfg_prjname=`echo $cfg_prjname | ${AWKEXE} '{print tolower(\$0);}'`;
fi

if [ -z "$cfg_filename" ]; then
	# use default
	cfg_filename="config_"$cfg_prjname;
fi

set -f;
if [ $cfg_dbg -eq 1 ]; then echo 'params are ['$cfg_params']'; fi
cfg_filespec=$cfg_params;
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

echo 'Testing in project ['$cfg_prjname']...'
if [ $cfg_test -eq 1 ]; then
	for fname in $cfg_filespec; do
		if [ $cfg_dbg -eq 1 -o $cfg_test -eq 1 ]; then echo ' processing ['$fname']'; fi
		if [ -f $fname ]; then
			${AWKEXE} -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -v debug=$cfg_dbg -v showonly=1 -v testmodify=0 -f __foo_tmp.awk "$fname"
		fi;
	done
else
	# adjust files retrieved with given filespec
	for fname in $cfg_filespec; do
		if [ $cfg_dbg -eq 1 -o $cfg_test -eq 1 ]; then echo ' processing ['$fname']'; fi
		if [ -f $fname ]; then
			${AWKEXE} -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -v debug=$cfg_dbg -v showonly=1 -v testmodify=1 -f __foo_tmp.awk "$fname"
			if [ $? -eq 0 ]; then
				echo ' changing ['$fname']';
				mv "$fname" "$fname.bak";
				${AWKEXE} -v cfgname="$cfg_filename.h" -v pname="$cfg_prjname" -v iname="$fname" -f __foo_tmp.awk "$fname.bak"
			fi
		fi
	done
	# create config header file if not already existing
	if [ ! -f "$cfg_filename.h" ]; then
		${AWKEXE} -v pname="$cfg_prjname" '{ pnameup=toupper(pname); gsub("TMPL",pnameup); print}' $mypath/dllsup_.h > $cfg_filename.h
	fi
	# create config source file if not already existing
	if [ ! -f "$cfg_filename.cpp" ]; then
		${AWKEXE} -v pname="$cfg_prjname" '{ pnameup=toupper(pname); gsub("TMPL",pnameup); gsub("tmpl",pname); print}' $mypath/dllsup_.cpp > $cfg_filename.cpp
	fi
fi

rm -f __foo_tmp.awk
