#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# drives generation of tar depending on compile and target switches
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
	echo ' -t <dir> : directory to put testable project tree in, default is ['$USR_TMP/$PROJECTNAME']'
	echo ' -u <0|1> : delete testable project directory first, default 1'
	echo ' -d <0|1> : delete lines of unused configurations from files, default 0 - dont delete just uncomment'
	echo ' -m <0|1> : set to 1 if a full make should be performed, default is 0 do not make, use existing files'
	echo ' -c <0|1> : create distribution package, eg. tar-gz, default is 0'
	echo ' -o <dir> : directory for putting distribution package, default is ['${USR_TMP}/${PROJECTNAME}_CD']'
	echo ' -p <0|1> : delete distribution package directory first, default is 1'
	echo ' -v <ver> : suffix for directory name when creating distribution package, appended to config-name (-a param)'
	echo ' -b       : batch mode, do not ask just go on'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo ''
	exit 4;
}

cfg_dobatch=0;
cfg_tmpdir="";
cfg_deltmp=1;
cfg_and="";
cfg_delete=0;
cfg_make=0;
cfg_docd=0;
cfg_cddir="";
cfg_cleancd=1;
cfg_suffix="";
cfg_dbg=0;
# process command line options
while getopts ":a:bt:u:d:m:c:o:p:v:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		b)
			cfg_dobatch=1;
		;;
		t)
			cfg_tmpdir="${OPTARG}";
		;;
		u)
			cfg_deltmp=${OPTARG};
		;;
		d)
			cfg_delete=${OPTARG};
		;;
		m)
			cfg_make=${OPTARG};
		;;
		c)
			cfg_docd=${OPTARG};
		;;
		o)
			cfg_cddir="${OPTARG}";
		;;
		p)
			cfg_cleancd=${OPTARG};
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
			. $mypath/config.sh $cfg_opt;
			showhelp;
		;;
	esac
done
shift $(($OPTIND - 1))

# load global config
. $mypath/config.sh $cfg_opt

# test if we need to set some default values
if [ -z "$cfg_tmpdir" ]; then
	cfg_tmpdir="${USR_TMP}/${PROJECTNAME}";
fi
if [ $cfg_docd -eq 1 -a -z "$cfg_cddir" ]; then
	cfg_cddir="${USR_TMP}/${PROJECTNAME}_CD";
fi

echo 'using following params:'
echo ''
echo 'temporary dir for testable prj tree:  ['$cfg_tmpdir']'
echo 'delete temporary dir before copying:  '$cfg_deltmp
echo 'configuration to use:                 ['$cfg_and'] of ['${ALL_CONFIGS}']'
echo 'removing other configurations         '${cfg_delete}
echo 'compile before copying:               '$cfg_make
echo 'make distribution in CD dir:          '$cfg_docd

if [ $cfg_docd -eq 1 ]; then
	echo 'directory to put CD files in:         ['$cfg_cddir']'
	echo 'delete CD dir before copying:         '$cfg_cleancd
	echo 'suffix to configuration:              ['$cfg_suffix']'
fi

if [ -z "$cfg_and" ]; then
	echo ''
	echo 'ERROR: configuration not specified, exiting !'
	showhelp;
fi

# if it's not batch-mode ask to continue
if [ $cfg_dobatch -eq 0 ]; then
	echo ''
	echo 'Continue using the settings above [y|n] (y)?'
	echo ''

	read contin
	# not empty means that some key was pressed
	if [ -n "$contin" -a ! "$contin" = "y" ]; then
		echo 'exiting'
		exit
	fi;
fi

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	cfg_toks=$cfg_toks" -a "$cfgtok;
done
cfg_and="$cfg_toks";

echo ''
echo '------------------------------------------------------------------------'
echo $MYNAME' - '$PRJ_DESCRIPTION
echo ''

if [ $cfg_make -eq 1 ]; then echo '* Compiling complete application'; fi
if [ $cfg_deltmp -eq 1 ]; then echo '* Deleting contents of temporary directory first'; fi

echo '* Copying distribution files to ['$cfg_tmpdir']'
echo '* Editing results for ['$cfg_and']'

if [ $cfg_docd -eq 1 ]; then
	echo '* Create distribution package'
	if [ $cfg_cleancd -eq 1 ]; then echo '* Deleting contents of distribution directory first'; fi
fi
echo ''

if [ $cfg_make -eq 1 ]; then
	echo ' ---- Making project in ['$PROJECTDIR']'
	$SCRIPTDIR/BuildProject.sh $cfg_opt $cfg_and
fi

if [ $cfg_docd -eq 1 ]; then
	echo ' ---- cleaning distribution directory'
	# clean cfg_cddir if requested
	if [ $cfg_cleancd -eq 1 -a -d "$cfg_cddir" ]; then
		rm -rf $cfg_cddir 2>/dev/null
	fi
	# create CD directory if it does not yet exist
	if [ ! -d "$cfg_cddir" ]; then
		mkdir -p "$cfg_cddir" 2>/dev/null
		if [ $? -ne 0 ]; then
			echo 'WARNING: could not create package directory ['$cfg_cddir']'
			cfg_docd=0;
		fi
	fi
fi

# copy distribution files to temporary directory
echo ' ---- copying all files'
$SCRIPTDIR/cpall.sh $cfg_opt -t "$cfg_tmpdir" -d $cfg_deltmp $cfg_and

# use specified configuration to customize some distribution files
echo ' ---- editing configs'
if [ -d "$cfg_tmpdir" ]; then
	( cd $cfg_tmpdir && $SCRIPTDIR/setConfig.sh -l "$cfg_tmpdir/$LOGDIR/edit.log" -d $cfg_delete $cfg_and $cfg_opt )
fi

if [ $cfg_docd -eq 1 ]; then
	echo ' ---- doing distribution package'
	$SCRIPTDIR/mktz.sh $cfg_opt -t "$cfg_tmpdir"

	# cp utilities scripts and tar to final cd directory
	echo ' ---- copying distribution package to distribution dir'
	$SCRIPTDIR/finalcp.sh $cfg_opt -t "$cfg_tmpdir" -c "$cfg_cddir" $cfg_and -n "$SERVERNAME" -v "$cfg_suffix"
fi

echo ''
echo '------------------------------------------------------------------------'
echo ''
