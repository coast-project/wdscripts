#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# cp necessary files for delivery into a temporary directory
#
# YOU SHOULD NOT HAVE TO MODIFY THIS FILE, BECAUSE THIS ONE IS HELD GENERIC
# MODIFY $CONFIGDIR/prjcopy.sh INSTEAD
#
############################################################################

MYNAME=`basename $0`

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" = "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [ options]'
	echo 'where options are:'
	echo ' -a <name>: config which must be defined, multiple definitions allowed'
	echo ' -d <0|1> : delete testable project directory first, default 1'
	echo ' -t <dir> : directory to put testable project tree in, default is ['$USR_TMP/$PROJECTNAME']'
	echo ' -D       : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_tmpdir="";
cfg_and="";
cfg_deltmp=1;
cfg_dbg=0;
# process command line options
while getopts ":a:t:d:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}"-a "${OPTARG};
		;;
		d)
			cfg_deltmp=${OPTARG};
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

# load global config
. $mypath/config.sh $cfg_opt

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - '$PRJ_DESCRIPTION
echo ''
echo 'Making temporary directories in ['$cfg_tmpdir']'
echo ''

# clean temporary dir if specified
if [ $cfg_deltmp -eq 1 -a -d "$cfg_tmpdir" ]; then
	echo ' ---- Cleaning temporary directory'
	rm -rf $cfg_tmpdir 2>/dev/null
fi

# create temporary directory if it does not yet exist
if [ ! -d "$cfg_tmpdir" ]; then
	mkdir -p "$cfg_tmpdir" 2>/dev/null
	if [ $? -ne 0 ]; then
		echo 'ERROR: creation of ['$cfg_tmpdir'] failed, exiting!'
		exit 4;
	fi
fi

# need to export TMPDIR variable because it is needed from other scripts...
export TMPDIR=$cfg_tmpdir

###########################################################################
#
# create and copy generic things which should be common to all projects
# especially scripts and configuration

echo ' ---- Making project directories'
if [ "$LOGDIR" = "." ]; then
	tmpLogDir=logs
else
	tmpLogDir=${LOGDIR}
fi

for mkdirname in $cfg_tmpdir/bin $cfg_tmpdir/${CONFIGDIR:-config} $cfg_tmpdir/lib $cfg_tmpdir/scripts $cfg_tmpdir/$tmpLogDir; do
	printf "  --- %-8s [%s] ... " "mkdir" "$mkdirname"
	mkdir $mkdirname 2>/dev/null
	if [ $? -eq 0 ]; then
		printf "done\n"
	else
		printf "failed\n"
	fi
done

echo ' ---- Copying binaries'
for cpfilname in $WDS_BIN $WDA_BIN; do
	if [ -f "$cpfilname" -a -x "$cpfilname" ]; then
		printf "  --- %-8s [%s] ... " "copying" "$cpfilname"
		cp -p $cpfilname $cfg_tmpdir/bin 2>/dev/null
		if [ $? -eq 0 ]; then
			printf "done\n"
		else
			printf "failed\n"
		fi
	fi
done
# copy libraries
for cpfilname in ${WD_LIBDIR}/*${DLLEXT}; do
	if [ -f "$cpfilname" -a -x "$cpfilname" ]; then
		printf "  --- %-8s [%s] ... " "copying" "$cpfilname"
		cp -p $cpfilname $cfg_tmpdir/lib 2>/dev/null
		if [ $? -eq 0 ]; then
			printf "done\n"
		else
			printf "failed\n"
		fi
	fi
done

echo ' ---- Copying scripts'
for cpfilname in $PROJECTSRCDIR/*.sh $PROJECTSRCDIR/*.pl $SCRIPTDIR/*; do
	if [ -f "$cpfilname" ]; then
		printf "  --- %-8s [%s] ... " "copying" "$cpfilname"
		cp -p $cpfilname $cfg_tmpdir/scripts 2>/dev/null
		if [ $? -eq 0 ]; then
			printf "done\n"
		else
			printf "failed\n"
		fi
	fi
done

echo ' ---- Copying config files'
oldifs="$IFS";
IFS=":";
for cfgseg in $WD_PATH; do
	IFS=$oldifs;
	if [ -d "$PROJECTDIR/$cfgseg" ]; then
		mkdir -p $cfg_tmpdir/$cfgseg;
		for cpfilname in $PROJECTDIR/$cfgseg/*.sh $PROJECTDIR/$cfgseg/*.any; do
			if [ -f "$cpfilname" ]; then
				printf "  --- %-8s [%s] ... " "copying" "$cpfilname"
				cp -p $cpfilname $cfg_tmpdir/$cfgseg 2>/dev/null
				if [ $? -eq 0 ]; then
					printf "done\n"
				else
					printf "failed\n"
				fi
			fi
		done
	fi;
done;

# now let the project specific subscript copy its additional things
if [ ! -f "$CONFIGDIRABS/prjcopy.sh" ]; then
	echo ''
	echo 'WARNING:'
	echo ' project specific copy file ['$CONFIGDIRABS/prjcopy.sh']'
	echo ' could not be found, thus copying only generic part'
	echo ''
else
	echo ''
	echo ' ---- Executing project specific prjcopy.sh'
	# first switch config of prjcopy to copy only the right things
	if [ -n "$cfg_and" ]; then
		$mypath/editConfig.sh -p "$CONFIGDIRABS" -e 'prjcopy.sh' $cfg_and -f "$ALL_CONFIGS" $cfg_opt >/dev/null 2>&1;
	fi
	. $CONFIGDIRABS/prjcopy.sh
fi

echo ' ---- Changing mode of config files'
oldifs="$IFS";
IFS=":";
for cfgseg in $WD_PATH; do
	IFS=$oldifs;
	find $cfg_tmpdir/$cfgseg -type f -exec chmod 444 {} 2>/dev/null \;
	find $cfg_tmpdir/$cfgseg -name '*.any' -type f -exec chmod 664 {} 2>/dev/null \;
	find $cfg_tmpdir/$cfgseg -name '*.sh' -type f -exec chmod 775 {} 2>/dev/null \;
done;

echo ' ---- Changing mode of script files'
find $cfg_tmpdir/scripts -type f -exec chmod 444 {} 2>/dev/null \;
chmod 775 $cfg_tmpdir/scripts/*.sh 2>/dev/null
chmod 775 $cfg_tmpdir/scripts/*.pl 2>/dev/null
chmod 664 $cfg_tmpdir/scripts/*.awk 2>/dev/null

echo ''
echo '------------------------------------------------------------------------'
echo ''
