#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# script checks result of dailyBuild and updates environment accordingly
#
############################################################################

# go to the home directory
cd

# source in the users setup defining UPDATEDIRS CVSFLAGS WDCORE and WDPROJS
if [[ -a .automaticUpdate ]]; then
. .automaticUpdate
fi

cd -

WDTESTER_HOME=${WDTESTER_HOME:-"/home/wdtester"}

DAILYBUILD_RESULT=${DAILYBUILD_RESULT:-"DailyBuildResult"}

let DOUPDATE=$(cat $WDTESTER_HOME/$DAILYBUILD_RESULT)

`dirname $0`/updateFromCVS.sh $DOUPDATE


