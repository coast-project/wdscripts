#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# generate final tar.gz file
#
############################################################################

MYNAME=`basename $0 .sh`

if [ $# -lt 1 ] ; then
	echo
	echo usage: $MYNAME tmpdir
	echo
	exit 3;
fi

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

cat <<EOT
----------------------------------------------------
$MYNAME - $PRJ_DESCRIPTION

Making $TARGZNAME of $PROJECTNAME
----------------------------------------------------
EOT

TMPDIR=$1

cd $TMPDIR
tar cvfz $TARGZNAME --exclude "$LOGDIR/*.log" --exclude "$LOGDIR/*.PID" *
cd -

cat <<EOT1
----------------------------------------------------
Testing contents
----------------------------------------------------
EOT1
tar tvfz $TMPDIR/$TARGZNAME

#cat <<EOT1
#----------------------------------------------------
#Splitting file
#----------------------------------------------------
#EOT1
#split -b 1423k $TMPDIR/gz/fds_tar.gz gz/FDS

cat <<EOT1
----------------------------------------------------
$MYNAME - $PRJ_DESCRIPTION
End
----------------------------------------------------
EOT1
