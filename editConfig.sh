#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# used to strip specific lines from files specified
#
############################################################################

MYNAME=`basename $0 .sh`
if [ $# -lt 5 ]; then
	echo
	echo usage: `basename $0` path extension logfilename deletelines"(0|1)" configflag all_configflags
	echo
	echo example: `basename $0` ~/tmp/config any ./edit.log 1 TKFOnly "'"TKFOnly itopiaOnly"'"
	echo
	exit 1;
fi;

path=$1
shift
ext=$1
shift

cat << EOT
------------------------------------
$MYNAME - switching configurations to $3 in $path
------------------------------------
EOT

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ $DNAM == ${DNAM#/} ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi
SCRIPTDIR=`cd $mypath 2> /dev/null && pwd`

for i in $path/*.$ext
do
	if [ -f $i ]; then
		echo $i
		echo "File " $i "....." >> $1
		tmpfilename=/tmp/tmpFile.$$.`basename $i`
		awk -v set_config="$3" -v all_config="$4" -v logfile="$1" -v forceDeletion="$2" -f $SCRIPTDIR/editany.awk "$i" > "$tmpfilename"
cat << EOT
------------------------------------
diff - $i and the new file
------------------------------------
EOT
		diff -U0 -b -B -w "$i" "$tmpfilename"
		diffRes=$?
		if [ "$diffRes" != 0 ]; then 
			if [ -w "$i" ]; then 
				cp "$tmpfilename" "$i"
			else
				chmod u+w "$i"
				cp "$tmpfilename" "$i"
				chmod u-w "$i"
			fi
		fi;
		rm -f "$tmpfilename"
	fi;
done

cat << EOT
------------------------------------
$MYNAME - End
------------------------------------
EOT
