#!/bin/sh
#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2006, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# catches informations on a running process
# - currently it outputs pflags, pfiles and pstack traces
#

showhelp()
{
	echo "usage: $0 -p <process> -f <outfile> [-s <sleepinterval>] [-a]"
	echo 'options are:'
	echo '-a          : append to outputfile, default overwrite'
	echo '-f <name>   : file in which to output'
	echo '-p <procid> : process id'
	echo '-s <secs>   : seconds to sleep between pstack calls'
	exit 1
}
do_append=0;
sleepinterval=0;
proc=0;
outfile="";
while getopts ":ap:f:s:" opt; do
        case $opt in
                a)
                        do_append=1;
                ;;
                p)
                        proc=$OPTARG
                ;;
                f)
                        outfile=$OPTARG
                ;;
                s)
                        sleepinterval=$OPTARG
                ;;
                \?)
                        showhelp
                ;;
        esac
done
shift `expr $OPTIND - 1`

if [ $proc -eq 0 -o -z "${outfile}" ]; then
	showhelp;
fi;

echo "tracing process $proc"
echo "Output in file  $outfile"
echo "Sleepinterval   $sleepinterval"
if [ $do_append -ne 1 ]; then
	echo "Emptying  file  $outfile now."
	rm $outfile
	touch $outfile
fi;

while true
do
	date >> $outfile
	/usr/proc/bin/pmap $proc >> $outfile
	echo "============================================================" >> $outfile
	/usr/proc/bin/pflags $proc >> $outfile
	echo "------------------------------------------------------------" >> $outfile
	/usr/proc/bin/pfiles $proc >> $outfile
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $outfile
	type -fP c++filt >/dev/null 2>&1;
	if [ $? -eq 0 ]; then
		/usr/proc/bin/pstack $proc | c++filt >> $outfile
	else
		/usr/proc/bin/pstack $proc >> $outfile
	fi;
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> $outfile
	if [ $sleepinterval -eq 0 ]; then
		break;
	fi;
	echo "Sleeping $sleepinterval seconds..."
	sleep $sleepinterval
done

