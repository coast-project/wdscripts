#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2001 itopia
# All Rights Reserved
#
# $Id$
#
# check WorkingEnvData.sniff to see if user already has a PWE with the given
# name
#
############################################################################

# script requires 3 params:

# $1: Name of the user (usrname)
# $2: Name of the WorkingEnvironment (pwename)
# $3: Path to the source location (srcdir)

# variable SNIFF_DIR must be set!!

# AWK-Script to parse SNIFFs WorkingEnv file (${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff)
# for the current user
cat <<EOF >awkin.foo
BEGIN{
	RS="WorkingEnv";
	FS="\r?\n";
	mstr="\"" usrname "\"";
	bUsrFound=0;
	bCreateEntry=1;
	bFirst=1;
}
{
	if (mode == "check")
	{
		if (match(\$0,mstr))
		{
			for (i=1; i< NF; i++)
			{
				if (match(\$i,"\t*Owner"))
				{
					split(\$i, ARR, "\"");
#					print "name is: #" ARR[2] "#";
					if (ARR[2] == usrname)
					{
#						print "usr found";
						bUsrFound=1;
						continue;
					}
					break;
				}
				if (match(\$i,"\t*Name"))
				{
					split(\$i, ARR, "\"");
#					print "pwe is: #" ARR[2] "#";
					if ( ARR[2] == pwename )
					{
#						print "srcdir found";
						bCreateEntry=0;
					}
				}
			}
		}
	}
	else if (mode == "append")
	{
		if (bFirst)
		{
			printf ("%s", \$0);
			print "WorkingEnv ("
			print "		CrispProjects   : array ( ),"
			print "		Name            : \"" pwename "\","
			print "		Owner           : \"" usrname "\","
			print "		PWS             : \"" sourcedir "\","
			print "		ParsingStrategy : 1,"
			print "		Platform        : \"itopia-Solaris-egcs-shared-dbg\","
			print "	),"
			printf("\t");
			bFirst=0;
		}
		else
		{
			printf ("%s%s", RS, \$0);
		}
	}
}
END{ if (bUsrFound==1 && bCreateEntry==0) exit 0; else exit 1; }
EOF

SNIFF_DIR=/home/sniff+
awk -v usrname="$1" -v mode="check" -v pwename="$2" -v sourcedir="$3" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff

if [ $? -ne 0 ]; then
	echo "working environment data for user $1 not found, adding new WorkingEnvironment..."
	cp ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff.bk
	awk -v usrname="$1" -v mode="append" -v pwename="$2" -v sourcedir="$3" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff.bk > ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff
#	awk -v usrname="$1" -v mode="append" -v pwename="$2" -v sourcedir="$3" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvData.sniff > gagaData.env
fi

rm -f awkin.foo
