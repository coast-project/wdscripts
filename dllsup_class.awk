#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
BEGIN{ RS="\r?\n"; mystr="^[ \t]*#include "; rstr="#include \"" cfgname "\""; strclass="^[ \t]*class[ \t]+"; ffirst = 1; found=0;}
{
	if (showonly != 1)
	{
		if (ffirst == 1 && match($0,mystr))
		{
			if (!match($0, rstr))
				print rstr > iname;
			ffirst = 0;
		}
	}
	if (match($0,strclass))
	{
		lcount=1;
		ARR[lcount] = $0;
		bidx=0;cidx=0;
		while ((bidx=match(ARR[lcount],"{"))==0 && (cidx=match(ARR[lcount],";"))==0)
		{
			getline ARR[++lcount];
		}
		if (bidx)
		{
			replstr="EXPORTDECL_" toupper(pname);
			if (!match(ARR[1],replstr))
			{
				if ((showonly == 1) && !match(ARR[1],"EXPORTDECL_")) {
					found=1;
					if (testmodify != 1)
						print " " ARR[1];
				}
				else
				{
					if (testmodify != 1)
						found=1;
					replstr = "&" replstr " ";
					gsub (strclass,replstr,ARR[1]);
				}
			}
		}
		if (showonly != 1)
		{
			for (i=1;i <= lcount; i++)
				print ARR[i] > iname;
		}
		delete ARR;
	}
	else
	{
		if (showonly != 1)
			print > iname;
	}
}
END { if (found) exit 0; else exit 1;}
