#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# cp installation files into corresponding CD directory
#
############################################################################

MYNAME=`basename $0 .sh`

if [ "$1" == "?" -o "$1" == "help" -o $# -lt 3 ]; then
	echo
	echo usage: $MYNAME tmpdir CDdir configuration versionSuffix
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
copying installation files into corresponding CD directory
----------------------------------------------------
EOT

TMPDIR=$1
CDDIR=$2
CONFFLAG=$3
MAKEFLAG=${4}

INSTALLDIR=$CDDIR/${CONFFLAG}${MAKEFLAG}

mkdir -p $INSTALLDIR

echo "Install dir: $INSTALLDIR"
echo "Tar:         $TARGZNAME"
echo "SCRIPTS:     $SCRIPTDIR"
echo

# cp utilities scripts and tar to final cd directory
# use platform correct gunzip binary
case "${CURSYSTEM}" in
	SunOS)
	GUNZIPBIN=$SCRIPTDIR/gunzip.bin.SunOS
	;;
	Linux)
	GUNZIPBIN=$SCRIPTDIR/gunzip.bin.Linux
	;;
	unknown)
	GUNZIPBIN=$SCRIPTDIR/gunzip.bin.SunOS
	;;
esac

echo "cp $GUNZIPBIN $INSTALLDIR/gunzip.bin"
cp $GUNZIPBIN $INSTALLDIR/gunzip.bin

echo "cp $SCRIPTDIR/install.sh $INSTALLDIR"
cp "$SCRIPTDIR/install.sh" $INSTALLDIR

echo "cp $SCRIPTDIR/config.sh $INSTALLDIR"
cp "$SCRIPTDIR/config.sh" $INSTALLDIR

echo "cp $CONFIGDIR/prjconfig.sh $INSTALLDIR"
cp "$CONFIGDIR/prjconfig.sh" $INSTALLDIR

echo "cp $CONFIGDIR/prjinstall.sh $INSTALLDIR"
cp "$CONFIGDIR/prjinstall.sh" $INSTALLDIR

echo "cp $TMPDIR/$TARGZNAME $INSTALLDIR"
mv $TMPDIR/$TARGZNAME $INSTALLDIR

cat <<EOT
----------------------------------------------------
end - $MYNAME - $PRJ_DESCRIPTION

----------------------------------------------------
EOT
