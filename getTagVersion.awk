# Erzeugt output des Filenamen mit gefundenem Tag zur aktuellen working revision
#  bei mehreren Eintr„gen wird der genommen mit der Struktur vx_xx
#  Grundlage ist ein mit 'cvs status -v' erzeugtes file
#
# Parameter:
#  sep    : eigener separator m÷glich anstelle von Space " "
#  width  : Breite der ersten Spalte sonst so breit wie n÷tig
#
# Beispiele von Ausgabetexten
# BPC386WIN.HX v1_85 (1.1)
# F_STRING.OBJ vx_xx (1.1)
# L386.obj v1_00 (1.1)
# gugus v1_00+ (1.2)
#
function isFirstOlder(wrev,trev,  WRDEC, TRDEC, ndecwr, ndectr, isok)
{
	ndecwr = split(wrev,WRDEC,"\.");
	ndectr = split(trev,TRDEC,"\.");
	isok = 1;
	for (decidx = 1; decidx <= ndecwr && decidx <= ndectr; decidx++)
	{
		if (TRDEC[decidx]+0 > WRDEC[decidx]+0)
		{
			isok = 0;
		}
	}
	if (isok)
	{
		if (ndectr > ndecwr)
		{
			isok = 0;
		}
	}
	return isok;
}
BEGIN {
	RS="===================================================================";
	if (!outname)
	{
		outname="version.txt";
	}
}
{
	if (sep)
	{
		OFS=sep;
	}
	nsp = split($0,LINEARR,"\r?\n");
	if (nsp > 0)
	{
#		print "nsp"nsp
		# line 2  : contains filename and status
		# line 4  : contains working revision
		# line 11+: contains Tag entries
		split(LINEARR[2],ARR);
		fname = ARR[2];
		modified = match(LINEARR[2], "Status: Locally Modified");
#		print "name : "fname;
		split(LINEARR[4],ARR,"\t");
		wrev = ARR[2];
#		print "wver : "wrev;
		cnt = 0;
		txt = "";
		max = 0;
		for (i=11;i < nsp; i++)
		{
			# process tag entries and fill them into VERTAG array
			split(LINEARR[i],ARR,"\t");
			split(ARR[3],VER,"[ \)]");
			rev = VER[2];
			if (match(ARR[2],"^v[0-9](_[0-9]+)+"))
			{
#				print LINEARR[i];
				tag = substr(ARR[2],RSTART,RLENGTH);
#				print rev,tag
				if (wrev == rev)
				{
					txt = tag;
					break;
				}
				else
				{
#					print "wrev:"wrev,"rev:"rev;
					if (isFirstOlder(wrev,rev))
					{
						max = rev;
						txt = tag;
#						print "max:"max,"tag:"txt;
						break;
					}
				}
#				print "ver  : "rev"#"tag"#";
			}
		}
		if (txt == "")
		{                               
			# still nothing found -> was never tagged
#			txt = "vx_xx";
		}
		if (fullinfo)
		{
			wrev = "(" wrev;
			if (modified)
			{
				wrev = wrev "*";
			}
			wrev = wrev ")";
			if (max)
			{
				txt = txt "(" max ")";
			}
		}
		else
		{
			wrev = "";
			if (modified || max)
			{
				txt = "*";
			}
			else
			{
				txt = "";
			}
		}
		if (width)
		{
			format= "%-" width "s";
			fname = sprintf(format,fname);
		}
		print fname,txt,wrev > outname;
	}
}
END {}
