#-----------------------------------------------------------------------------------------------------
# Copyright (c) 2005, Peter Sommerlad and IFS Institute for Software at HSR Rapperswil, Switzerland
# All rights reserved.
#
# This library/application is free software; you can redistribute and/or modify it under the terms of
# the license that is included with this library/application in the file license.txt.
#-----------------------------------------------------------------------------------------------------
BEGIN{ RS="\r?\n"; mystr="^[ \t]*#include "; incstr="^[ \t]*#include[ \t]+\"config_"; rstr="#include \"" cfgname "\""; strclass="^[ \t]*class[ \t]+"; ffirst = 1; found=0;}
{
	# check for correct inclusion of config_xxx.h
	if (ffirst == 1 && match($0,mystr))
	{
		ffirst = 0;
		# first include line detected, check if it is already our needed include
		if (!match($0, rstr))
		{
			if (!match(iname, cfgname))
				found=1;
			if (showonly != 1)
			{
				# print new include line anyways
				print rstr > iname;
			}
			# include did not match, check if an include of another lib still resides in the file
			if (match($0, incstr))
			{
				if (testmodify != 1)
					print "  need to replace old include ["$0"]";
				# in this case we need to skip outputting the current line in buffer
				next;
			}
		}
	}
	if (match($0,strclass))
	{
		lcount=1;
		ARR[lcount] = $0;
		bidx=0;cidx=0;
		# check if it is a class definition or just a forward class
		while ((bidx=match(ARR[lcount],"{"))==0 && (cidx=match(ARR[lcount],";"))==0)
		{
			getline ARR[++lcount];
		}
		if (bidx)
		{
if (debug) print "matched class in [" $0 "]";
if (debug) { for (i=1;i <= lcount; i++) print "line:"i" "ARR[i]; }
			replstr="EXPORTDECL_" toupper(pname);
			if (!match(ARR[1],replstr))
			{
				found=1;
				replstr = "&" replstr " ";
if (debug) print "before replace [" ARR[1] "]";
				# EXPORTDECL did not match, either it is the wrong one or it isnt there
				if (!match(ARR[1],"EXPORTDECL_"))
				{
					# no EXPORTDECL found
					if (testmodify != 1)
						print "  " ARR[1];
				}
				else
				{
					# wrong EXPORTDECL, replace
					if (testmodify != 1)
						print "  correcting " ARR[1];
					split(ARR[1],FLD,"EXPORTDECL_[A-Z]+[ \t]+");
					ARR[1]=FLD[1] FLD[2];
				}
				sub (strclass,replstr,ARR[1]);
if (debug) print "replaced part [" ARR[1] "]";
			}
		}
		else
		{
if (debug) print "matched forward class in [" $0 "]";
		}
		if (showonly != 1)
		{
			# print the lines we already read in
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
