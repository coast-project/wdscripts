#!/usr/local/bin/perl
##!/usr/bin/perl5.8
##!/usr/bin/perl
use warnings;
use strict;
use Fcntl; 
use Getopt::Long;
my %h = ();
sub help()
{
  print "Use CTRL-C to query intermediate results or to stop  pstacker.\n";
  die "usage: $0 -sleep <seconds>  -proc <process id> -regex <regex>"; 
}  
if ( scalar @ARGV == 0)
{
	&help();
}		
GetOptions (\%h, 'sleep|s:i',  'procid|p=i', 'regex|r:s', 'ofile|o:s') || &help();

my $sleep = $h{sleep}; 
my $procid = $h{procid};
my $filter = $h{regex};
my $ofile  = $h{ofile};

defined $procid or die "You must give the proces id.";
defined($sleep) or $sleep = 10;
if ( !defined $ofile )
{
	$ofile = "/tmp/pstacker.txt";
}

$SIG{INT}  = \&print_summary_stdout;
my  (%result,$pass);
%result = ();
$pass=0;
while (1) 
{
	print "Doing pass : ",$pass++,"\n";
	&doit;
	sleep($sleep);
}
sub doit()
{
	my ($i,$ii,$flatcallstack,@separators,%pstack,@stackinfo,$index);
	@stackinfo = ();
	@separators = ();
	%pstack = ();
	@ARGV= ("/usr/proc/bin/pstack  $procid |");
	$index = 0;
	while (<>)
	{
#		print ($_);
		if (/^-------/)
		{
			@separators = split;
			$index++;
		}
		else
		{
			@stackinfo = split;
			if ( $#stackinfo > 0 )
			{	
				push @{ $pstack{$index} },$stackinfo[1];
			}
		}
	}
	foreach $i (keys %pstack )
	{
			$flatcallstack = "@{$pstack{$i}}";
			$result{$flatcallstack}++;
	}
	&print_summary(0);
}

sub print_summary_stdout()
{
	&print_summary(1);
} 
sub print_summary()
{
	my ($ctrlc) = @_;
	my ($count,$callstack,$fh);
	if ( $ctrlc )
	{
		$fh = *STDOUT;
	}
	else
	{
		open(OFILE, "> $ofile") or die "Unable to open file $ofile\n";
		$fh = *OFILE;
	}
	foreach $callstack (sort { $result{$a} <=> $result{$b} } keys %result) 
	{
		if ( !defined $filter || ( defined $filter && $callstack =~ /$filter/ ) )
		{
			print  $fh  ("$result{$callstack} LWP's found in:\n");	
			print  $fh  (join "\n" , split / /, $callstack);
			print  $fh  ("\n--------------------------------------------\n");
		}
	}
	if ( !$ctrlc )
	{
		close(OFILE);
	}
	else
	{
		my $answer;
		print $fh "Do you want to stop? [no]\n";
		chomp ($answer = <STDIN>);
		print $fh "The answer was: [$answer]\n";
		print $fh "Output is saved in: $ofile\n";
		if ( $answer =~ /yes/	 )
		{
			exit 0;
		}
		else
		{
			&doit();
		}
	}
}
