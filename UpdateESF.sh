#!/bin/bash

SDIR=`dirname $0`
. ${SDIR}/envForTests.sh
NOTIFY_EMAIL=eSportSup@itopia.ch
DEVDIR=/home/wdtester/Linux/DevServer/eSportFoundation

cd $DEVDIR
stopwds.sh | mail -s 'ESF stopped' $NOTIFY_EMAIL

cd ${DEV_HOME}/WWW/eSportFoundation

doall.sh -t "$DEVDIR" -a "ATT" -b

cd $DEVDIR
startwds.sh > Start.out 2>&1
cat Start.out |  mail -s 'ESF started' $NOTIFY_EMAIL
