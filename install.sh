#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# install the current distribution and optionally link the directory
#
############################################################################

MYNAME=`basename $0 .sh`

if [ "$1" == "?" -o "$1" == "help" -o $# -lt 1 ]; then
	echo
	echo usage: $MYNAME installdir [linkdir]
	echo
	exit 3;
fi

# load configuration for current project
. `dirname $0`/config.sh

if [ $? -ne 0 ]; then
	printf "configuration with %s failed\n" `dirname $0`/config.sh;
	exit 4;
fi

GUNZIP=${GUNZIP:-./gunzip.bin}
CURRENT_DIR=`pwd`
if [ ! -z $2 ]; then
	LINK_PATH=$2
fi
INSTALLDIRABS=$1
INSTALLDIRREL=${INSTALLDIRABS##*/}

cat << EOT
-------------------------------------
currently in `pwd`
installing $PROJECTNAME in $INSTALLDIRABS
using: $GUNZIP $TARGZNAME
EOT

if [ -d $INSTALLDIRABS ]; then
	echo "$INSTALLDIRABS exists"
	echo "bailing out..."
	exit 2;
else
	printf "creating %s... " $INSTALLDIRABS
	mkdir -p $INSTALLDIRABS
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 1
	else
		printf "done\n"
	fi
fi

if [ -f $TARGZNAME ]; then
	printf "copying %s to %s ... " $TARGZNAME $INSTALLDIRABS 
	cp ./$TARGZNAME $INSTALLDIRABS
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 1
	else
		printf "done\n"
	fi	
else
	printf "%s does not exist in %s\n" $TARGZNAME $CURRENT_DIR
	exit 1
fi

if [ -f $GUNZIP ]; then
	printf "unzipping %s in %s ... " $TARGZNAME $INSTALLDIRABS
	$GUNZIP $INSTALLDIRABS/$TARGZNAME
	if [ $? -ne 0 ]; then
		printf "failed\n"
		exit 1
	else
		TARGZNAME=${TARGZNAME%%.tgz}.tar
		printf "done\n"
	fi
else
	printf "%s not found\n" $GUNZIP
fi

echo "changing directory to $INSTALLDIRABS"
cd $INSTALLDIRABS

echo "extracting $TARGZNAME ..."
tar xvf $TARGZNAME
if [ $? -ne 0 ]; then
	echo "extraction failed"
	exit 1
fi

rm $TARGZNAME

###########################################################################

# do project specific installing
if [ ! -f $CURRENT_DIR/prjinstall.sh ]; then
cat << EOT
--------------------------------------------------
WARNING:
project specific install file
>> $CURRENT_DIR/prjinstall.sh
could not be found, thus only doing generic parts
--------------------------------------------------
EOT
fi

if [ -f $CURRENT_DIR/prjinstall.sh ]; then
	. $CURRENT_DIR/prjinstall.sh
fi

###########################################################################
# generic again

# check if we have to link a directory
cd $INSTALLDIRABS
if [ ! -z ${LINK_PATH} ]; then
	echo "now in `pwd`"
	echo "changing to .."
	cd ..
	if [ -L ${LINK_PATH} ]; then
		echo "removing existing link"
		rm ${LINK_PATH}
	fi;
	echo "setting symbolic link ${LINK_PATH} to ${INSTALLDIRREL}"
	ln -s ${INSTALLDIRREL} ${LINK_PATH}
	cd ${LINK_PATH}
fi

echo "-------------------------------------"
echo "installation done; don't forget to configure backends"
