#!/bin/ksh
###########################################################################
# Copyright (c) 1999-2001 itopia
# All Rights Reserved
#
# $Id$
#
# check WorkingEnvUser.sniff to see if user already has permissions to 
# create a PWE
#
############################################################################

# script requires 1 param:

# $1: Name of the user (usrname)

# variable SNIFF_DIR must be set!!

# AWK-Script to parse SNIFFs WorkingEnv file (${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff)
cat <<EOF >awkin.foo
BEGIN{
	RS="WorkingEnvUser";
	FS="\r?\n";
	mstr="\"" usrname "\"";
	bUsrFound=0;
	bPWEok=0;
	bFirst=1;
}
{
	if (mode == "check")
	{
		if (match(\$0,mstr))
		{
			for (i=1; i< NF; i++)
			{
				# get the WorkingEnv name
				if (match(\$i,"\t*Name"))
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
				# get the root of the project
				if (match(\$i,"\t*Permission_PWE"))
				{
					split(\$i, ARR, ":");
#					print "pwe is: #" ARR[2] "#";
					if ( match(ARR[2], "1") )
					{
#						print "perm ok";
						bPWEok=1;
					}
					break;
				}
			}
		}
	}
	else if (mode == "append")
	{
		if (bFirst)
		{
			printf ("%s", \$0);
			print "WorkingEnvUser ("
			print "		Name            : \"" usrname "\","
			print "		Permission_PWE  : 1,"
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
END{ if (bUsrFound==1 && bPWEok==1) exit 0; else exit 1; }
EOF

SNIFF_DIR=/home/sniff+
awk -v usrname="$1" -v mode="check" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff

if [ $? -ne 0 ]; then
	echo "PWE permissions for user ${usrname} not found, adding permissions to create PWE..."
	cp ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff.bk
	awk -v usrname="$1" -v mode="append" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff.bk > ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff
#	awk -v usrname="$1" -v mode="append" -f awkin.foo ${SNIFF_DIR}/workingenvs/WorkingEnvUser.sniff > gagaUser.sniff
fi

rm -f awkin.foo
