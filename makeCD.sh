#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# create file structure to deploy
#
############################################################################

MYNAME=`basename $0 .sh`
if [ "$1" = "help" -o "$1" = "?" ] ; then
	echo
	echo "usage: $MYNAME [CDdir]"
	echo
	exit 0;
fi

if [ ! -z "$1" ]; then
	CDDIR=${1}
fi

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

cat <<EOT
--------------------------------------------
$MYNAME - itopia
Creating all versions of output for CD

--------------------------------------------
EOT

# to do issues - autotag each CD burning
# and add new version number, edit into Any.

$SCRIPTDIR/doall.sh -a "TKFQA" -d 1 -c 1 -o "$CDDIR" -v "1.1dbg"		# use current files
#$SCRIPTDIR/doall.sh -a "TKFQA" -d 1 -c 1 -o "$CDDIR" -v "1.1dbg" -m 1	# compile before copying

cat <<EOT
--------------------------------------------
end $MYNAME - itopia

--------------------------------------------
EOT
