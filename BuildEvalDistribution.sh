#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2001 itopia
# All Rights Reserved
#
# $Id$
#
# drives generation of complete WebDisplay2 distribution for a customer to
# testdrive
#
############################################################################

MYNAME=`basename $0 .sh`

if [ "$1" == "help" -o "$1" == "?" ] ; then
cat <<EOT
-----------------------------------------------------------------------------------------

usage:

$MYNAME.sh
<tmpDir>        - default "~/tmp/deploy" - directory for temporary storing all files

-----------------------------------------------------------------------------------------
EOT
exit
fi

packfiles=myfiles.tx
cmprs='tar cf - -v -T $packfiles | gzip > $OUTFILE'
cmprsext=.tgz
TMPDIR=${1:-~/tmp/deploy}
CURDATE=`date +%Y%m%d%H%M`
OUTFILE=WebDisplay2_${CURDATE}${cmprsext}

# check if the caller already used an absolute path to start this script
DNAM=`dirname $0`
if [ "$DNAM" == "${DNAM#/}" ]; then
# non absolute path
	mypath=`pwd`/$DNAM
else
	mypath=$DNAM
fi
# points to the directory where the scripts reside
SCRIPTDIR=`cd $mypath 2> /dev/null && pwd`

exitproc()
{
	rm -f ${TMPDIR}/${packfiles}
	rm -f ${TMPDIR}/_repl.sed
	exit 0;
}

trap exitproc INT

checkpath()
{
	while true; do
		while [ -z ${PATHVAR} ]; do
			printf "%s is undefined. Please enter the new value: " "${PATHVAR_NAME}"
			read PATHVAR
		done
		if [ "${PATHVAR}" == "${PATHVAR#\~}" ]; then
			# first char is not ~
			if [ "${PATHVAR}" == "${PATHVAR#/}" ]; then
				# first char is not /: rel path
				if [ -d ${PATHVAR} ]; then
					PATHVAR=`cd ${PATHVAR} && pwd`
#					echo path now is 1: ${PATHVAR}
					break;
				else
					printf "Directory %s does not exist, create it [y|n](n)?" "${PATHVAR}"
					read yesno
					if [ "$yesno" == "y" -o "$yesno" == "Y" ]; then
						mkdir -p "${PATHVAR}"
					else
						PATHVAR=
					fi
				fi
			else
				# first char is / : abs path
				if [ -d ${PATHVAR} ]; then
#					echo path now is 2: ${PATHVAR}
					break;
				else
					printf "Directory %s does not exist, create it [y|n](n)?" "${PATHVAR}"
					read yesno
					if [ "$yesno" == "y" -o "$yesno" == "Y" ]; then
						mkdir -p "${PATHVAR}"
					else
						PATHVAR=
					fi
				fi
			fi
		else
			# first char is ~
			PATHVAR=`cd && pwd`${PATHVAR#\~}
			if [ -d ${PATHVAR} ]; then
#				echo path now is 3: ${PATHVAR}
				break;
			else
				printf "Directory %s does not exist, create it [y|n](n)?" "${PATHVAR}"
				read yesno
				if [ "$yesno" == "y" -o "$yesno" == "Y" ]; then
					mkdir -p "${PATHVAR}"
				else
					PATHVAR=
				fi
			fi
		fi
	done
	printf "%s is set to: %s\n" "${PATHVAR_NAME}" "${PATHVAR}"
	return
}

PATHVAR=${SNIFF_DIR}
PATHVAR_NAME="SNiFF Dir"
checkpath
SNIFF_DIR=${PATHVAR}

cat <<EOT

-------------------------------------------------
using following params:

temporary dir for sources:  $TMPDIR
filename of distribution:   $OUTFILE
SNiFF+ installation dir:    $SNIFF_DIR


! temporary dir will be cleaned !
-------------------------------------------------

Continue using the settings above [y|n] (y)?
EOT

read contin
if [ "$contin" == "n" ]; then
	exit
fi;

if [ -d ${TMPDIR} ]; then
cat <<EOT
-------------------------------------------------

removing files in temporary dir...
EOT
	rm -rf ${TMPDIR}
fi

mkdir ${TMPDIR}
cd ${TMPDIR}

cat <<EOT
-------------------------------------------------

checking out core files...
EOT

cvs co WDCore

echo copying current htdocs...
cp -r /home2/change/htdocs/WD2Doku .
echo

echo copying webdisplay word-document
cp /home2/change/pc23.nt/Projects/webdisplay/dokuWD2/WD2Documentation0948.doc .

NUMOFKBYTES=`du -s | awk '{ print $1 }'`

find . "(" -path '*CVS' ")" -prune -o ! "(" -name "${packfiles}" ")" -type f -print >${packfiles}

eval $cmprs

GUNZIPBIN=$SCRIPTDIR/gunzip.bin.SunOS

echo "cp $GUNZIPBIN ${TMPDIR}/gunzip.bin"
cp $GUNZIPBIN ${TMPDIR}/gunzip.bin

cat <<EOT > _repl.sed
s/##REPLACE_GZNAME##/${OUTFILE}/g
s/##REPLACE_DATE##/${CURDATE}/g
s/##REPLACE_NUMOFKBYTES##/${NUMOFKBYTES}/g
EOT

sed -f _repl.sed ${SCRIPTDIR}/EvalInstall.sh > ${TMPDIR}/EvalInstall.sh
chmod u+x ${TMPDIR}/EvalInstall.sh

cp ${SCRIPTDIR}/CheckWEUser.sh ${TMPDIR}
cp ${SCRIPTDIR}/CheckWEData.sh ${TMPDIR}

cat <<EOT >cpfiles.tx
cp ${SNIFF_DIR}/make_support/general.mk ${TMPDIR}/make_support
cp ${SNIFF_DIR}/make_support/general.link.mk ${TMPDIR}/make_support
cp ${SNIFF_DIR}/make_support/general.c.mk ${TMPDIR}/make_support
cp ${SNIFF_DIR}/make_support/sparc-sun-solaris2.6.egcs.mk ${TMPDIR}/make_support
cp ${SNIFF_DIR}/Preferences/Platforms/itopia-Solaris-egcs-shared-dbg.sniff ${TMPDIR}/Preferences/Platforms

cp /usr/local/src/gcc/gcc-2.95.2.tar.gz ${TMPDIR}
cp /usr/local/src/openssl/openssl-0.9.6.tar.gz ${TMPDIR}
cp /usr/local/src/ldap/ldapsdk-41-SOLARIS_5.6-export-ssl.tar.gz ${TMPDIR}
EOT

mkdir -p ${TMPDIR}/make_support
mkdir -p ${TMPDIR}/Preferences/Platforms

cat cpfiles.tx
. cpfiles.tx

rm -f cpfiles.tx

exitproc
