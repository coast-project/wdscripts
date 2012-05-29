#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# script to do a search and replace in files
#

MYNAME=`basename $0`

mypath=`dirname $0`
test "/" = "`echo ${mypath} | cut -c1`" || mypath=`pwd`/${mypath}

showhelp()
{
	echo ''
	echo 'usage: '$MYNAME' [options] <files...>'
	echo 'where options are:'
	echo ' -r <replace string> : specify replacement string'
	echo ' -s <search string> : specify search string'
	echo ' -T : test only, do not replace'
	echo ''
	exit 4;
}

cfg_test=0;
rstr="";
# process command line options
while getopts ":r:s:T" opt; do
	case $opt in
		r)
			rstr="${OPTARG}";
		;;
		s)
			sstr="${OPTARG}";
		;;
		T)
			cfg_test=1;
		;;
		\?)
			showhelp;
		;;
	esac
done
shift `expr $OPTIND - 1`

# load os-specific settings and functions
. ${mypath}/sysfuncs.sh

IS_GNUAWK=0;
FINDEXE="`getFirstValidTool \"/usr/local/bin:/usr/bin:/bin\" gfind find`"
AWKEXE="`getFirstValidTool \"/usr/local/bin:/usr/bin:/bin\" gawk awk`"
hasVersionReturn "$AWKEXE" >/dev/null && IS_GNUAWK=1;

# check that we have GNU-awk available, otherways we can not execute the awk script
if [ $IS_GNUAWK -eq 0 ]; then
	echo '';
	echo 'ERROR:';
	echo ' could not locate gawk executable!';
	echo '';
	exit 4;
fi

while true; do
	# terminate loop after last file
	if [ -z "$1" ]; then break; fi;
	echo "processing '$1' files..."
	if [ $cfg_test -eq 0 ]; then
		${FINDEXE} "`dirname "$1"`" -name "`basename "$1"`" -type f -exec ${AWKEXE} -v sstr="$sstr" -v iname="{}" 'BEGIN{found=0;}{ if (match($$0,sstr)) found=1; }END{ if (found) { print "+ replacing in " iname; exit 0;} else exit 1;}' "{}" \; -exec mv "{}" "{}.bak" \; -exec ${AWKEXE} -v sstr="$sstr" -v rstr="$rstr" -v iname="{}" "{ gsub(sstr,rstr); print > iname;}" "{}.bak" \;
	else
		${FINDEXE} "`dirname "$1"`" -name "`basename "$1"`" -type f -exec ${AWKEXE} -v sstr="$sstr" -v iname="{}" 'BEGIN{found=0;}{ if (match($$0,sstr)) found=1; }END{ if (found) { print "+ TEST replacing in " iname; exit 0;} else exit 1;}' "{}" \;
	fi;
	shift;
done
