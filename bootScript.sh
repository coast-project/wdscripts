#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
#
# specify SCRIPTDIR and copy this script to /sbin/init.d ( for System V )
#

. /etc/rc.config

# The echo return value for success (defined in /etc/rc.config).
return=$rc_done

export SERVICENAME=$PROJECTNAME
export SCRIPTDIR=/home/scripts

case "$1" in
    start)
	echo -n "Starting service $SERVICENAME"
	$SCRIPTDIR/startwds.sh > /dev/null 2>&1 || return=$rc_failed

	echo -e "$return"

    ;;
    stop)
	echo -n "Shutting down service $SERVICENAME"
	$SCRIPTDIR/stopwds.sh  > /dev/null 2>&1 || return=$rc_failed
	echo -e "$return"
    ;;
    restart)
	echo -n "Restart service $SERVICENAME"
	$SCRIPTDIR/restartwds.sh  > /dev/null 2>&1 ||  return=$rc_failed
	echo -e "$return"
    ;;
    reload)
	echo -n "Reload service $SERVICENAME"
	$SCRIPTDIR/SoftRestart.sh  > /dev/null 2>&1 || return=$rc_failed
	echo -e "$return"
    ;;
   *)
    echo "Usage: $0 {start|stop|restart|reload}"
    exit 1
esac

# Inform the caller not only verbosely and set an exit status.
test "$return" = "$rc_done" || exit 1
exit 0

