BEGIN {
	RS="============================================================================="; 
	FS="----------------------------";
	first = 1;
	revstr = substr(revstr,3);
#	print revstr;
	tofieldsub = 0;
	fname = "ChangeLog_";
	if (match(revstr,":"))
	{
		tofieldsub = 1;
		nsp = split(revstr,ARR,":");
		if (ARR[1] != "")
			fname = fname ARR[1] "-";
		if (ARR[2] != "")
		{
			if (ARR[1] == "")
			{
				fname = fname "-"; 
				tofieldsub = 0;
			}
			fname = fname ARR[2];
		}
	}
	else
		fname = fname revstr;
	if (bare)
		fname = fname "_short";
	fname = fname ".txt";
#	print fname;
}
{
	if (NF > 1)
	{
		if (!match($1,"cvs server: warning: no revision"))
		{   
			msgprinted = 0;
			split($1,ARR,"\r?\n");
			if (first)
				fnline = 3;
			else
				fnline = 4;
			split(ARR[fnline],FNA,": ");
			filname = FNA[2];
			# check if file is attic
			mystart=1;
			if (match(filname,".*/"))
				mystart = RLENGTH+1;
			atticname = "Attic/" substr(filname,mystart);
			if (!match(ARR[fnline-1], atticname))
			{
				split(ARR[fnline+1],FNA,": ");
				rev = FNA[2];
				prnnam = 1;
				tofield = NF - tofieldsub;
				# loop over log messages
				for (i=2;i <= tofield; i++)
				{
					nsp = split($i,ARR,"\r?\n");
					# line containing log message starts at index 4 or 5 if we have a branch
					idxmsg = 4;
					if (match(ARR[idxmsg],"^branches:"))
						idxmsg += 1;
					# don't print empty log message
					if (!match(ARR[idxmsg],"^[.]") && !match(ARR[idxmsg],"\*\*\* empty log message \*\*\*"))
					{
						if (prnnam == 1)
						{
							print filname > fname;
#							print filname,"("rev")" > fname;
							prnnam = 0;
						}
						if (!bare)
							print "\t----------------" > fname;

						split(ARR[2],RA," ");
						rev = RA[2];
						# print the log message
						# if we start at index 2 we also print revision and additional information
						# if we start at index 4 or 5 we only print the message itself
						if (bare)
						{
							start=idxmsg;
							print "  "rev":" > fname;
						}
						else
							start=2;
						for (j=start; j < nsp; j++)
						{
							if (!match(ARR[j],"^branches:"))
							{
								print "\t"ARR[j] > fname;
								msgprinted = 1;
							}
						}
					}
				}
			}
		}
		if (msgprinted)
			print "" > fname;
		if (first)
			first = 0;
	}
}
END {}
