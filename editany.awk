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
#
############################################################################
function switchIT( CURRENTLINE, OPTION, DELFLAG ) { 	
	dd = CURRENTLINE;
	printf("we want [%s], current is [%s] in line: [%s]%s", set_config, OPTION, dd, ORS) >> logfile;

	# if TKF set as input and option is TKF
	# if itopia set as input and option is itopia
	if ( OPTION == set_config ) 
	{
		printf(" writing [") >> logfile;
		#print "set was " set_config " and it matched" >> logfile
		if ( 0 !~ n = index( $1, "#" ) )
		{
			# remove first comment from line
			sub( /#/, "", dd )
	 	}
		DELFLAG = 0;	
	}
	else
	{
		#print "set was " set_config " and it did not match" >> logfile
		# if no comment at start of line..
		if ( 0 ~ n = index( $1, "#" ) )
		{
			# add comment
			dd = "#" $0
	 	}	
		if ( DELFLAG ~ 0 )
			printf(" disabling [") >> logfile;
		else
			printf(" deleting [") >> logfile;
	}

	# sometimes resulting line should be suppressed
	if ( DELFLAG ~ 0 )
	{
		print dd
	}
	printf("%s] %s", dd, ORS) >> logfile;
}
BEGIN {
	# strip leading and trailing '
	gsub("'","",all_config);
	n_configs=split(all_config,ALL_CFG);
}
{
	if (match($0,"#"))
	{
		patternStart="^.*[^ \t].*#[^#]*[ \t]";
		patternEnd="([ \t]|$)";
		patternSet = patternStart set_config patternEnd;
		if (match($0,patternSet))
		{
			switchIT( $0, set_config, forceDeletion );
			next;
		} else {	
			for (i in ALL_CFG)
			{
				dis_config = patternStart ALL_CFG[i] patternEnd;
				if (match($0,dis_config))
				{
					# if it's the one to set don't look any further
					switchIT( $0, ALL_CFG[i], forceDeletion );
					next;
				}
			}
		}
	}
	print $0;
}
 
 
END { close( logfile ) }
