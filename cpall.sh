#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# cp necessary files for delivery into a temporary directory
#
# YOU SHOULD NOT HAVE TO MODIFY THIS FILE, BECAUSE THIS ONE IS HELD GENERIC
# MODIFY $CONFIGDIR/prjcopy.sh INSTEAD
#
############################################################################

MYNAME=`basename $0 .sh`
if [ -z $1 ]; then
	echo
	echo "usage: $MYNAME tempdir [deletefirst(yes|no)]"
	echo
	exit 0;
fi

TMPDIR=$1
DELTMPDIR=${2:-no}

shift

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

cat <<EOT
--------------------------------------------------
$MYNAME - $PRJ_DESCRIPTION

Making temporary directories under $TMPDIR/
where deployed files are temporarily stored
--------------------------------------------------
EOT

# clean temporary dir if specified
if [ "$DELTMPDIR" == "yes" -a -d "$TMPDIR" ]; then
	rm -rf $TMPDIR
fi

# create temporary directory if it does not yet exist
if [ ! -d "$TMPDIR" ]; then
	mkdir -p "$TMPDIR"
fi

###########################################################################
#
# create and copy generic things which should be common to all projects
# especially scripts and configuration

mkdir $TMPDIR/bin
mkdir $TMPDIR/config
mkdir $TMPDIR/lib
mkdir $TMPDIR/scripts
mkdir $TMPDIR/${LOGDIR}

if [ -f $WDS_BIN ]; then cp $WDS_BIN $TMPDIR/bin; fi
if [ -f $WDA_BIN ]; then cp $WDA_BIN $TMPDIR/bin; fi

cp $CONFIGDIR/*.sh $TMPDIR/config
cp $CONFIGDIR/*.any $TMPDIR/config

chmod 664 $TMPDIR/config/*any
chmod 775 $TMPDIR/config/*sh

#copy scripts
cp $PROJECTDIR/src/*.sh $TMPDIR/scripts
cp $PROJECTDIR/src/*.pl $TMPDIR/scripts
cp $SCRIPTDIR/*.sh $TMPDIR/scripts
cp $SCRIPTDIR/*.pl $TMPDIR/scripts
cp $SCRIPTDIR/*.awk $TMPDIR/scripts
chmod 775 $TMPDIR/scripts/*sh
chmod 775 $TMPDIR/scripts/*pl
chmod 664 $TMPDIR/scripts/*awk

# cp lib entries
cp $LIBDIR/*${DLLEXT} $TMPDIR/lib

# now let the project specific subscript copy its additional things

if [ ! -f $CONFIGDIR/prjcopy.sh ]; then
cat << EOT
--------------------------------------------------
ERROR:
project specific copy file
>> $CONFIGDIR/prjcopy.sh
could not be found, thus copying only generic part
--------------------------------------------------
EOT
else
. $CONFIGDIR/prjcopy.sh
fi

cat <<EOT1
--------------------------------------------
$MYNAME - $PRJ_DESCRIPTION
End
--------------------------------------------
EOT1
