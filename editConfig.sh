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

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options]'
	echo 'where options are:'
	echo ' -a <name>: config which must be defined, multiple definitions allowed'
	echo ' -f "<all configs>" : set of all configs which might be selected for switching, enclose in double quotes'
	echo ' -c <string> : commenting string, default "'$cfg_comment'"'
	echo ' -e <fileextension> : extension of files which will be config-switched, multiple options may be specified'
	echo ' -p <directory> : directories in which files to be replaced get searched, multiple options may be specified'
	echo ' -l <logfilename> : file in which changes will be logged, if not specified changes wont be logged'
	echo ' -d <0|1> : delete lines of unused configurations from file, default 0 - dont delete just uncomment'
	echo ' -t <dir> : directory to put temporary files in, default is system tmp directory ['$SYS_TMP']'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_path="";
cfg_ext="";
cfg_logfile="";
cfg_delete=0;
cfg_and="";
cfg_full="";
cfg_dbg=0;
cfg_tmpdir="";
cfg_comment="#";
# process command line options
while getopts ":c:e:p:l:d:a:f:t:D" opt; do
	case $opt in
		c)
			cfg_comment="${OPTARG}";
		;;
		e)
			if [ -n "$cfg_ext" ]; then
				cfg_ext=${cfg_ext}":";
			fi
			cfg_ext=${cfg_ext}${OPTARG};
		;;
		p)
			if [ -n "$cfg_path" ]; then
				cfg_path=${cfg_path}":";
			fi
			cfg_path=${cfg_path}${OPTARG};
		;;
		l)
			cfg_logfile="${OPTARG}";
		;;
		d)
			cfg_delete=${OPTARG};
		;;
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		f)
			cfg_full="${OPTARG}";
		;;
		t)
			cfg_tmpdir="${OPTARG}";
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

# set and check if we can write into tmp-directory, else we wont be able to create the changed files
cfg_tmpdir=${cfg_tmpdir:-$SYS_TMP};
if [ ! -d "$cfg_tmpdir" -a -n "$cfg_tmpdir" ]; then
	# try to create temporary directory
	mkdir -p $cfg_tmpdir 2>/dev/null;
	if [ $? -ne 0 ]; then
		# failed, empty tmpdir to abort script
		echo ''
		echo 'ERROR: could not create tmpdir ['$cfg_tmpdir'] !'
		cfg_tmpdir="";
	fi
fi
if [ -n "$cfg_tmpdir" -a -d "$cfg_tmpdir" ]; then
	# now touch a testfile to see if we can write to it
	touch $cfg_tmpdir/touchtstfile 2>/dev/null;
	if [ $? -ne 0 ]; then
		# failed, empty tmpdir to abort script
		echo ''
		echo 'ERROR: can not write to tmpdir ['$cfg_tmpdir'] !'
		cfg_tmpdir="";
	else
		rm $cfg_tmpdir/touchtstfile
	fi
fi

# set and check if we can write into logfile
if [ -n "$cfg_logfile" ]; then
	# now touch the logfile to see if we can write to it
	touch $cfg_logfile 2>/dev/null;
	if [ $? -ne 0 ]; then
		# failed, empty cfg_logfile to not use the log file
		echo ''
		echo 'WARNING: can not write to logfile ['$cfg_logfile']'
		cfg_logfile="";
	fi
fi

if [ $cfg_dbg -eq 1 ]; then
	echo ''
	echo 'params:'
	echo ''
	echo 'path ['$cfg_path']'
	echo 'ext  ['$cfg_ext']'
	echo 'logf ['$cfg_logfile']'
	echo 'del  ['$cfg_delete']'
	echo 'cfg  ['$cfg_and']'
	echo 'full ['$cfg_full']'
	echo 'tmpd ['$cfg_tmpdir']'
	echo 'cmtc ['$cfg_comment']'
	echo ''
fi

if [ -z "$cfg_ext" ]; then
	echo 'ERROR: file extension(s) not defined, exiting!'
	showhelp;
fi

if [ -z "$cfg_path" ]; then
	echo 'ERROR: path not defined, exiting!'
	showhelp;
fi

if [ -z "$cfg_and" ]; then
	echo 'ERROR: configuration not defined, exiting!'
	showhelp;
fi

if [ -z "$cfg_full" ]; then
	echo 'ERROR: you must define all possible configurations, exiting!'
	showhelp;
fi

if [ -z "$cfg_tmpdir" ]; then
	echo 'ERROR: tempdir not defined, exiting!'
	showhelp;
fi

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - switching configurations to ['$cfg_and'] in path ['$cfg_path'] for filespecs ['$cfg_ext']'
echo ''

oldifs="$IFS"
IFS=":"
# do on all given directories
for curdir in $cfg_path; do
	# cut a trailing slash if any
	curdir=${curdir%/};
	if [ -n "$curdir" -a -d "$curdir" ]; then
		echo ' ---- directory ['$curdir'] ----'
		# do on all given file-specifiers
		# temporary disable pathname expansion of shell because files in the current directory with
		#  the same extension would already be expanded :-(
		set -f;
		for curext in $cfg_ext; do
			if [ -n "$curext" ]; then
				echo '  --- filespec   ['$curext'] --- '
				# do for each file
				# re-enable pathname expansion because we want it here
				set +f;
				for filname in $curdir/$curext; do
					if [ -f "$filname" ]; then
						echo '   -- testing     ['$filname']'
						tmpfilename=$cfg_tmpdir/tmpFile.$$.`basename $filname`
						# awk returns the count of changed lines, so if it stays 0 nothing changed at all
						awk -v set_config="$cfg_and" -v all_config="$cfg_full" -v logfile="$cfg_logfile" -v forceDeletion="$cfg_delete" -v comment="$cfg_comment" -f $SCRIPTDIR/editany.awk "$filname" > "$tmpfilename"
						if [ $? -ne 0 ]; then
							# check for a real difference
							echo '    - diffing     ['$filname'] and the temporary file ['$tmpfilename']'
							diff -U0 -b -B -w "$filname" "$tmpfilename"
							diffRes=$?;
							if [ $diffRes -ne 0 ]; then
								# the file has changed
								echo '     + changed    ['$filname']'
								if [ -n "$cfg_logfile" ]; then
									echo "changed file "$filname >> $cfg_logfile
								fi
								# check if we can write the file
								if [ -w "$filname" ]; then
									cp "$tmpfilename" "$filname"
								else
									chmod u+w "$filname"
									cp "$tmpfilename" "$filname"
									chmod u-w "$filname"
								fi
							fi;
						fi
						rm -f "$tmpfilename"
					fi
				done
			fi
		done
	else
		echo ' ---- directory ['$curdir'] does not exist!'
	fi
done
echo '------------------------------------------------------------------------'
echo ''
