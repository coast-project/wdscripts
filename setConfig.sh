#!/bin/ksh
# 
# sets the Config to first param or the project Default (set DEF_CONF in prjconfig.sh)

. `dirname $0`/config.sh

CONF=${1:-$DEF_CONF}
cd $PROJECTDIR;

$SCRIPTDIR/editConfig.sh $CONFIGDIR any $LOGDIR/edit.log 0 $CONF "$ALL_CONFIGS" 
$SCRIPTDIR/editConfig.sh $CONFIGDIR sh $LOGDIR/edit.log 0 $CONF "$ALL_CONFIGS" 
$SCRIPTDIR/editConfig.sh $PROJECTDIR/src sh $LOGDIR/editsh.log 0 $CONF "$ALL_CONFIGS"
$SCRIPTDIR/editConfig.sh $PROJECTDIR/src pl $LOGDIR/editpl.log 0 $CONF "$ALL_CONFIGS" 
$SCRIPTDIR/editConfig.sh $PROJECTDIR/FunkTest sql $LOGDIR/editsql.log 0 $CONF "$ALL_CONFIGS" 
$SCRIPTDIR/editConfig.sh $PROJECTDIR/FunkTest sh $LOGDIR/editsh.log 0 $CONF "$ALL_CONFIGS" 
$SCRIPTDIR/editConfig.sh $PROJECTDIR/FunkTest/config any $LOGDIR/editany.log 0 $CONF "$ALL_CONFIGS" 
