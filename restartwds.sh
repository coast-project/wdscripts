#!/bin/ksh

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

$SCRIPTDIR/stopwds.sh
$SCRIPTDIR/startwds.sh
