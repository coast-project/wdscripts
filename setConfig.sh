#!/bin/ksh
# 
# sets the Config to first param or the project Default (set DEF_CONF in prjconfig.sh)

MYNAME=`basename $0`

function showhelp
{
	echo ''
	echo 'usage: '$MYNAME' [options] [config]'
	echo 'where options are:'
	echo ' -a <config> : config which you want to switch to, multiple definitions allowed'
	echo ' -d <0|1> : delete lines of unused configurations from file, default 0 - dont delete just uncomment'
	echo ' -l <logfile>: specify location and name of logfile, default is ['${PROJECTDIR:-PROJECTDIR}/${LOGDIR:-LOGDIR}'/edit.log]'
	echo ' -D : print debugging information of scripts, sets PRINT_DBG variable to 1'
	echo 'where config is:'
	echo ' <config> : config which you want to switch to, similar to -a <config> but only one param used'
	echo ''
	exit 4;
}

cfg_and="";
cfg_opt="";
cfg_dbg=0;
cfg_delete=0;
cfg_filename="";
# process command line options
while getopts ":a:d:l:D" opt; do
	case $opt in
		a)
			if [ -n "$cfg_and" ]; then
				cfg_and=${cfg_and}" ";
			fi
			cfg_and=${cfg_and}${OPTARG};
		;;
		d)
			cfg_delete=${OPTARG};
		;;
		l)
			cfg_filename=${OPTARG};
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

# if a param is specified use it regardless of -a switches
if [ -n "$1" ]; then
	cfg_and="${1}";
fi

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

# if config is still not specified, use the DEF_CONF value
if [ -z "$cfg_and" ]; then
	cfg_and=$DEF_CONF;
fi

# if config is still undefined show a help message
if [ -z "$cfg_and" ]; then
	showhelp;
fi

# prepare configuration param, need to add -a before each token
cfg_toks="";
for cfgtok in $cfg_and; do
	if [ $cfg_dbg -eq 1 ]; then echo 'curseg is ['$cfgtok']'; fi
	cfg_toks=$cfg_toks" -a "$cfgtok;
done
cfg_and="$cfg_toks";
if [ -z "${cfg_filename}" ]; then
	cfg_logdir=`cd $PROJECTDIR/$LOGDIR 2>/dev/null && pwd`;
	cfg_filename=${cfg_logdir}/edit.log;
fi

# if the file prjconfig exists, first switch it - it might contain switchable data - and then re-source the config.sh
if [ -d "$PRJCONFIGPATH" -a -f "$PRJCONFIGPATH/prjconfig.sh" ]; then
	echo ' - switching prjconfig.sh'
	$SCRIPTDIR/editConfig.sh -p "$PRJCONFIGPATH" -e 'prjconfig.sh' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
	echo ' - re-sourcing config.sh'
	. $mypath/config.sh $cfg_opt
fi

if [ -d "$PROJECTDIR" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR" -e '*.sh' -e '*.bat' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
fi
oldifs="$IFS";
IFS=":";
for cfgseg in $WD_PATH; do
	IFS=$oldifs;
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR/$cfgseg" -e '*.any' -e '*.sh' -e '*.sql' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
done;
if [ -n "$PROJECTSRCDIR" -a -d "$PROJECTSRCDIR" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTSRCDIR" -e "*.pl" -e '*.sh' -e '*.pm' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
fi
if [ -d "$PROJECTDIR/FunkTest" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR/FunkTest" -e '*.sql' -e '*.sh' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
fi
if [ -d "$PROJECTDIR/FunkTest/config" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR/FunkTest/config" -e '*.any' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
fi
if [ -d "$PROJECTDIR/scripts" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR/scripts" -e '*.awk' -e '*.sh' -e '*.pl' -e '*.pm' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
fi
if [ -n "$PERFTESTDIR" -a -d "$PROJECTDIR/$PERFTESTDIR" ]; then
	$SCRIPTDIR/editConfig.sh -p "$PROJECTDIR/$PERFTESTDIR" -e '*.sh' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
	for subcfgname in `find "$PROJECTDIR/$PERFTESTDIR" -path "*config*" -type d`; do
		$SCRIPTDIR/editConfig.sh -p "$subcfgname" -e '*.any' -e '*.sh' -l "$cfg_filename" -d $cfg_delete $cfg_and -f "$ALL_CONFIGS" $cfg_opt
	done
fi
