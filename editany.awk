###########################################################################
# Copyright (c) 1999-2000 itopia
# All Rights Reserved
#
# $Id$
#
# used to strip specific lines from a file
#
# params: 
#   set_config    : specifies which configuration to enable in the file, all others in all_config are removed
#   all_config    : specifies all configurations
#   logfile       : file where changed files are logged
#   forceDeletion : (0|1) specifies if nonconfigured lines should be deleted
#   comment       : specify commenting string, default '#'
#
############################################################################
function checkMatch(line, cfg_and, doAnd, patternStart, patternEnd, patternSet, bmatch, nAnds, ANDCFG)
{
	patternStart="[ \t]";
	patternEnd="([ \t]|[ \t]*$)?";
	bmatch=0;
	if (match(line,comment))
	{
		nAnds=split(cfg_and, ANDCFG);
		for (i in ANDCFG)
		{
			#if (doLog) print "  testing ["ANDCFG[i]"]" >> logfile;
			patternSet = patternStart ANDCFG[i] patternEnd;
			if (match(line,patternSet))
			{
				bmatch=1;
				# if OR mode, terminate as soon as it matches
				if (!doAnd)
				{
					break;
				}
			}
			else
			{
				bmatch=0;
				# if AND mode, terminate as soon as it does not match
				if (doAnd)
				{
					break;
				}
			}
		}
	}
	return bmatch;
}
function enableLine(line)
{
	# only remove the first hash on line if we have at least two of them
	if (match(line, "^[ \t]*" comment ".*" comment))
	{
		sub(comment, "", line );
		if (doLog) print " enabling  ["line"]" >> logfile;
		bChanges++;
	}
	print line;
}
function disableLine(line, doDel)
{
	if (doDel)
	{
		# nothing but logging to do
		if (doLog) print " deleting  ["line"]" >> logfile;
		bChanges++;
	}
	else
	{
		# only add hash if there is none
		if (!match(line, "^[ \t]*" comment))
		{
			line = comment line;
			if (doLog) print " disabling ["line"]" >> logfile;
			bChanges++;
		}
		print line;
	}
}
BEGIN {
	# strip leading and trailing '
	gsub("'","",all_config);
	bChanges=0;
	doLog=0;
	if (logfile != "")
		doLog=1;
	if (comment == "")
		comment="#";
}
{
	if (checkMatch($0, set_config, 1))
	{
		enableLine($0);
		next;	# read next inputline
	}
	else if (checkMatch($0, all_config, 0))
	{
		disableLine( $0, forceDeletion );
		next;	# read next inputline
	}
	print $0;
}
END { if (doLog) close( logfile ); exit bChanges; }
