#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2001 itopia
# All Rights Reserved
#
# $Id$
#
# install the evaluation copy into a directory
#
############################################################################

MYNAME=`basename $0 .sh`

if [ "$1" = "?" -o "$1" = "help" ]; then
	echo
	echo usage: $MYNAME sourcedir sniff_dir
	echo
	exit 3;
fi

GUNZIP=${GUNZIP:-./gunzip.bin}
TARGZNAME=##REPLACE_GZNAME##
WDDATE=##REPLACE_DATE##
NUMOFKBYTES=##REPLACE_NUMOFKBYTES##
CURRENT_DIR=`pwd`
INSTALLDIRABS=$1

checkpath()
{
	while true; do
		while [ -z "${PATHVAR}" ]; do
			printf "%s is undefined. Please enter the new value: " "${PATHVAR_NAME}"
			read PATHVAR
		done
		if [ "${PATHVAR}" = "${PATHVAR#\~}" ]; then
			# first char is not ~
			if [ "${PATHVAR}" = "${PATHVAR#/}" ]; then
				# first char is not /: rel path
				if [ -d ${PATHVAR} ]; then
					PATHVAR=`cd ${PATHVAR} && pwd`
#					echo path now is 1: ${PATHVAR}
					break;
				else
					printf "Directory %s does not exist, create it [y|n](y)?" "${PATHVAR}"
					read yesno
					if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
						PATHVAR=
					else
						mkdir -p "${PATHVAR}"
					fi
				fi
			else
				# first char is / : abs path
				if [ -d ${PATHVAR} ]; then
#					echo path now is 2: ${PATHVAR}
					break;
				else
					printf "Directory %s does not exist, create it [y|n](y)?" "${PATHVAR}"
					read yesno
					if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
						PATHVAR=
					else
						mkdir -p "${PATHVAR}"
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
				printf "Directory %s does not exist, create it [y|n](y)?" "${PATHVAR}"
				read yesno
				if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
					PATHVAR=
				else
					mkdir -p "${PATHVAR}"
				fi
			fi
		fi
	done
	printf "%s is now set to: %s\n" "${PATHVAR_NAME}" "${PATHVAR}"
	return
}


cat <<EOT

================================================================================

                          ii  tt                 ii
                              tt
                       iii  tttttt  oooo  p ppp  ii  aaaa
                       ii     tt   oo  oo pp  pp ii     aa
                      ii      tt   oo  oo pp   p ii  aaaaa
                     ii       tt   oo  oo pp  pp ii aa  aa
                     iii       tt   oooo  p ppp  ii  aaa a
                                          pp
                                          pp

================================================================================

This installation script can be used to install the WebDisplay2 sources into a
directory. It further modifies some SNiFF make-support files to fix some
missing things and to extend them for easier usage with different make options
like debug/optimized or sharedlib/statically-linked targets without having to
create multiple <platform>.mk files.

As a prerequisite you should have installed the following software to test the
WebDisplay2 Framework:
* gcc (egcs) 2.95.2
* nsldap 4.1
* openssl 0.9.6

Appropriate tar.gz files are supplied with this installation that you should be
able to install them if you do not already have them installed.
If you decide to use parts of the framework which use the SSL- and LDAP- packages,
you have to specify following environment variables to point to the locations
where they have been installed to:
SSL_DIR  (e.g. "setenv SSS_DIR /home/ssl"   with c-shell or "export SSL_DIR=/home/ssl"  with k- or bash-shell)
LDAP_DIR (e.g. "setenv LDAP_DIR /home/ldap" with c-shell or "export SSL_DIR=/home/ldap" with k- or bash-shell)

To simplify setting various variables needed for building the sources there are
two files called itopia.csh and itopia.ksh which can be used to set them. They
are located in the directory where the sources are installed. Using
csh you can 'source' the itopia.csh file (e.g. "source itopia.csh"  from command line),
using ksh/bash you can '.' the itopia.ksh file (e.g. ". itopia.ksh" from command line).

EOT
printf "Please enter the name of the user for which the testing environment should be set\n"
printf "up. The current user name for which this would be set up is [%s].\n" "${USER}"
printf "If you want to change the user enter another user name or press RETURN to keep it.\n"
printf ">"
read NEWUSER
if [ -z "${NEWUSER}" ]; then
	NEWUSER=${USER}
fi
cat <<EOT

Next the source directory should be chosen so that this user has access to it
later. A new SNiFF WorkingEnvironment will be created automatically for this user.

EOT
PATHVAR=${INSTALLDIRABS}
PATHVAR_NAME="Installation Dir"
checkpath
INSTALLDIRABS=${PATHVAR}
INSTALLDIRREL=${INSTALLDIRABS##*/}

cat <<EOT

Finally we must know the path to the SNiFF+ installation directory to be able to
copy the make-support files and to modify the WorkingEnvironment files. Backup
copies will be made of the files replaced that you will be able to restore the
current version of the files.

EOT
PATHVAR=${SNIFF_DIR}
PATHVAR_NAME="SNiFF Dir"
checkpath
SNIFF_DIR=${PATHVAR}

cat <<EOT

-------------------------------------
SNIFF_DIR is set to:   [${SNIFF_DIR}]
INSTALL_DIR is set to: [${INSTALLDIRABS}]
your username is:      [${NEWUSER}]

required disk space for the sources is ${NUMOFKBYTES}kB

Continue extracting the sources [y|n] (y)?
-------------------------------------
EOT

read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
	exit
fi

cat <<EOT

currently in `pwd`
installing WebDisplay2 sources of $WDDATE into $INSTALLDIRABS
using: $GUNZIP $TARGZNAME

EOT

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
printf "going back to "
cd -

cat <<EOT >${INSTALLDIRABS}/itopia_vars.ksh
export DEV_HOME=${INSTALLDIRABS}
#export SSL_DIR=
#export LDAP_DIR=
EOT

cat <<EOT >${INSTALLDIRABS}/itopia_vars.csh
setenv DEV_HOME ${INSTALLDIRABS}
#setenv SSL_DIR
#setenv LDAP_DIR
EOT

echo ""
echo "-------------------------------------"
echo "backing up following files in SNiFF-Dir..."
echo ""

cat <<EOT > snffiles.tx
workingenvs/WorkingEnvUser.sniff
workingenvs/WorkingEnvData.sniff
make_support/general.mk
make_support/general.link.mk
make_support/general.c.mk
make_support/sparc-sun-solaris2.6.egcs.mk
Preferences/Platforms/itopia-Solaris-egcs-shared-dbg.sniff
EOT

#cat snffiles.tx     # not needed because tar already writes out the files being tar'ed

cd ${SNIFF_DIR}
tar cvf ${INSTALLDIRABS}/SNiFF_FilesBackup.tar -T ${CURRENT_DIR}/snffiles.tx

printf "going back to "
cd -
rm -f snffiles.tx

cat <<EOT >cpfiles.tx
cp ${CURRENT_DIR}/make_support/general.mk ${SNIFF_DIR}/make_support
cp ${CURRENT_DIR}/make_support/general.link.mk ${SNIFF_DIR}/make_support
cp ${CURRENT_DIR}/make_support/general.c.mk ${SNIFF_DIR}/make_support
cp ${CURRENT_DIR}/make_support/sparc-sun-solaris2.6.egcs.mk ${SNIFF_DIR}/make_support
cp ${CURRENT_DIR}/Preferences/Platforms/itopia-Solaris-egcs-shared-dbg.sniff ${SNIFF_DIR}/Preferences/Platforms
EOT

cat <<EOT

-------------------------------------
copying the following files to SNiFF-Dir:

EOT

cat cpfiles.tx

echo ""
echo "do you want to proceed [y|n] (y)?"

read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
	exit
fi

. cpfiles.tx
rm -f cpfiles.tx

pwename="itopia-WebDisplay2-Evaluation"
cat <<EOT

-------------------------------------
now checking/modifying sniff-WorkingEnvironment files

a new PrivateWorkingEnvironment, ${pwename}, will be created for ${NEWUSER}

do you want to proceed [y|n] (y)?
EOT

read yesno
if [ "$yesno" = "n" -o "$yesno" = "N" ]; then
	exit
fi

cd ${CURRENT_DIR}
./CheckWEUser.sh "${NEWUSER}"
./CheckWEData.sh "${NEWUSER}" "${pwename}" "${INSTALLDIRABS}"

cat <<EOT

installation done
================================================================================

EOT
