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

MYNAME=`basename $0 .sh`

if [ "$1" == "help" -o "$1" == "?" ] ; then
cat <<EOT
-----------------------------------------------------------------------------------------

usage:

$MYNAME.sh
<tmpDir>        - default "~/tmp/\$PROJECTNAME" - directory for testable project tree
<cleanTmpDir>   - [yes|no] - determine whether tmpdir is cleaned
<configuration> - configure which configuration to use, one of the configs specified in
                  \$ALL_CONFIGS variable (config.sh or prjconfig.sh)
<removeOtherCfg>- [0|1] - if 1, slots of other configurations will be removed from
                  all files touched with editConfig.sh
<performMake>   - [yes|no] - should a full make be performed?
<makeArchive>   - [no|yes] - should an installable distribution copy be generated
<ArchiveDir>    - default "/tmp/\$PROJECTNAME_CD" - directory in which to put
                  distribution content
<cleanArchiveDir> [yes|no] - determine whether distribution directory is cleaned before
                  the run
<versionSuffix> - suffix appended to the configuration param, could be 1.3opt and
                  would result in a TKFQA1.3opt subdirectory in the tmpDir directory
                  (only used when creating a CD distribution)

-----------------------------------------------------------------------------------------
EOT
exit
fi

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

TMPDIR=${1:-~/tmp/$PROJECTNAME}
DELTMPDIR=${2:-yes}
CONFFLAG=${3:-${DEF_CONF}}
RMOTHERCFG=${4:-0}
COMPILEFLAG=${5:-no}
MAKEDISTR=${6:-no}
CDDIR=${7:-/tmp/${PROJECTNAME}_CD}
DELCDDIR=${8:-yes}
MAKEFLAG=${9}

export CONFFLAG

cat <<EOT
-------------------------------------------------
using following params:

temporary dir for testable prj tree:  $TMPDIR
delete temporary dir before copying:  $DELTMPDIR
configuration to use:                 $CONFFLAG  of [${ALL_CONFIGS}]
removing other configurations         ${RMOTHERCFG}
compile before copying:               $COMPILEFLAG
make distribution in CD dir:          $MAKEDISTR
EOT
if [ "$MAKEDISTR" == "yes" ]
then
echo "directory to put CD files in:         $CDDIR"
echo "delete CD dir before copying:         $DELCDDIR"
echo "suffix to configuration:              $MAKEFLAG"
fi
cat <<EOT
-------------------------------------------------

Continue using the settings above [y|n] (y)?
EOT

read contin
if [ "$contin" == "n" ]; then
	exit
fi;

cat <<EOT
--------------------------------------------
$MYNAME - $PRJ_DESCRIPTION

EOT
if [ "$COMPILEFLAG" == "yes" ]; then echo "* Compiling complete application"; fi
if [ "$DELTMPDIR" == "yes" ]; then echo "* Deleting contents of temporary directory first"; fi
echo "* Copying distribution files to $TMPDIR"
echo "* Editing results for '$CONFFLAG'"
if [ "$MAKEDISTR" == "yes" ]; then
	echo "* Assembly of delivery CD directories"
	if [ "$DELCDDIR" == "yes" ]; then echo "* Deleting contents of CD directory first"; fi
fi
cat <<EOT

--------------------------------------------
EOT

if [ "$COMPILEFLAG" == "yes" ]; then
	echo "Making project in $PROJECTDIR"
	echo
	$SCRIPTDIR/BuildProject.sh
fi

if [ "$MAKEDISTR" == "yes" ]; then
	# clean CDDIR if requested
	if [ "$DELCDDIR" == "yes" -a -d "$CDDIR" ]; then
		rm -rf $CDDIR
	fi
	
	# create CD directory if it does not yet exist
	if [ ! -d "$CDDIR" ]; then
		mkdir -p "$CDDIR"
	fi
fi

# copy distribution files to temporary directory
$SCRIPTDIR/cpall.sh "$TMPDIR" "$DELTMPDIR"

# use specified configuration to customize some distribution files
if [ -d "$TMPDIR/config" ]; then
	$SCRIPTDIR/editConfig.sh "$TMPDIR/config" any "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	$SCRIPTDIR/editConfig.sh "$TMPDIR/config" sh "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
fi
if [ -d "$TMPDIR/scripts" ]; then
	$SCRIPTDIR/editConfig.sh "$TMPDIR/scripts" sh "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	$SCRIPTDIR/editConfig.sh "$TMPDIR/scripts" awk "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	$SCRIPTDIR/editConfig.sh "$TMPDIR/scripts" pl "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
fi
if [ -d "$TMPDIR/src" ]; then
	$SCRIPTDIR/editConfig.sh "$TMPDIR/src" sh "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	$SCRIPTDIR/editConfig.sh "$TMPDIR/src" pl "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
fi
if [ -d "$TMPDIR/perftest" ]; then
	$SCRIPTDIR/editConfig.sh "$TMPDIR/perftest" sh "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	for subcfgname in `find "$TMPDIR/perftest" -name "*config*" -type d`
	do
		$SCRIPTDIR/editConfig.sh "$subcfgname" any "$TMPDIR/$LOGDIR/edit.log" ${RMOTHERCFG} "$CONFFLAG" "'$ALL_CONFIGS'"
	done
fi

if [ "$MAKEDISTR" == "yes" ]
then
	$SCRIPTDIR/mktz.sh "$TMPDIR"

	# cp utilities scripts and tar to final cd directory
	$SCRIPTDIR/finalcp.sh $TMPDIR $CDDIR $CONFFLAG $MAKEFLAG
fi

cat <<EOT
--------------------------------------------
end $MYNAME - $PRJ_DESCRIPTION

--------------------------------------------
EOT
