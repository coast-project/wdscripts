#!/usr/local/bin/perl
##!/usr/bin/perl5.8
##!/usr/bin/perl
## Use dtrace with this script
##****************************
## if [ -z $1 ]
## then
##        echo "You must enter a PID"
##        exit 1
## fi
## dtrace -n "syscall::lwp_park:entry  /pid == $1/ { @[ustack(6)] = count() }" -o /tmp/dtrace_$1.txt

use warnings;
use strict;
use Fcntl; 
use Getopt::Long;
use List::Util qw/max min sum/;
my @files = ();
my %result = ();
my $mode = "max";
sub help()
{
  die "usage: $0 -files <files> -mode <max|delta>"; 
}  
if ( scalar @ARGV == 0)
{
	&help();
}		
GetOptions ('files|f=s' => \@files, 'mode|m:s' => \$mode) || &help();


@files or die "You must give at least one input file.";

foreach my $filename (@files)
{
	open(IFILE, "< $filename") or die "Unable  o read $filename\n";
	&doit($filename);
	close(IFILE);
}
&print_summary();
sub doit($)
{
	my ($filename) = @_;
	my $index = 0;
	my @stacktrace = ();
LINE:	while (my $line = <IFILE>)			
	{
		chomp $line;
		next LINE if $line =~ /^$/;
		  
		$line  =~ s/^\s+|\s+$//g;
		if ($line =~  /^(\d+)$/)
		{
			my $flatcallstack = join('',@stacktrace);
			$result{$flatcallstack}{"filenames"}{$filename}{"occurrences"} = $line;
			$result{$flatcallstack}{"lines"}  = [ @stacktrace ];
			@stacktrace = ();
			$index = 0;
		}
		else
		{
			$stacktrace[$index++] = $line;	
		}
	}
}

sub print_summary()
{
	my %final = ();
	foreach my $flatcallstack (keys %result) 
	{
		my @values = ();
		foreach my $filename (keys %{ $result{$flatcallstack}{"filenames"} }) 
		{
			push @values, $result{$flatcallstack}{"filenames"}{$filename}{"occurrences"};		
		}
		$result{$flatcallstack}{"total"} = sum(@values);
		$result{$flatcallstack}{"max"} = max(@values);
		$result{$flatcallstack}{"min"} = min(@values);
		$result{$flatcallstack}{"delta"} = $result{$flatcallstack}{"max"} - $result{$flatcallstack}{"min"};
		my $index;
		if ( $mode =~ /max/ )
		{
			$index = sprintf("%15d",$result{$flatcallstack}{"total"}) . $flatcallstack;
		}
		if ( $mode =~ /delta/ )
		{
			$index = sprintf("%15d",$result{$flatcallstack}{"delta"}) . $flatcallstack;
		}
		$final{$index}{$flatcallstack} = $result{$flatcallstack};	
	}
	foreach my $index (reverse sort (keys %final))
	{
		foreach my $flatcallstack (keys %{ $final{$index} }) 
		{
			print   (join "\n",@{ $final{$index}{$flatcallstack}{"lines"}});
			print ("\n");
			foreach my $filename (keys %{ $final{$index}{$flatcallstack}{"filenames"} }) 
			{
				printf  ("Filename: %30s Occurrences: %15d, Min: % 15d, Total: %15d, Delta: %15d\n",
					$filename,$final{$index}{$flatcallstack}{"filenames"}{$filename}{"occurrences"}, 
					$final{$index}{$flatcallstack}{"min"},
					$final{$index}{$flatcallstack}{"total"},$final{$index}{$flatcallstack}{"delta"});
			}
		}
	}
}
