#!/usr/bin/perl
#
#  $Id: slasher.pl,v 1.12 2004/09/10 23:57:33 dboardman Exp $
#

use strict;

# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use DDParserUtils;
use Getopt::Long;
use File::stat;

# Switch to this program's directory
chdir($Bin);

my $Days = 4;
my $Maindir = '.';
my $HeadendTextfileDir = './headend';
my $ListingsTextfileDir = './listings';
my $WriteGuide = '/home/svanderw/emulator/xmltv2tivo/writeguide';
my $Gzip = 0;

my $Username = "<insert username>"; #insert the username you chose at the subscription management website
my $Password = "<insert password>"; #insert the password you chose

my $ListingsDir = '/home/tivo/web/tivo-service/static/listings/';
my $HeadendDir = '/home/tivo/web/tivo-service/static/Headend/';
my $ListModTime = 1;
my $ValidTime;

my $Part = 2;
my $Verbose = 0;
my $GenerateShowcase;

GetOptions( 'days=i' => \$Days,
	    'listmodtime=i' => \$ListModTime,
	    'maindir=s' => \$Maindir,
	    'listings=s'=> \$ListingsDir,
	    'headend=s'=> \$HeadendDir,
	    'part=s'         => \$Part,
	    'valid=s'         => \$ValidTime,
	    'verbose+'       => \$Verbose,
	    'v+'             => \$Verbose,
	    'gzip=i' => \$Gzip,
	    'writeguide=s'=> \$WriteGuide,
	    'username=s'=> \$Username,
	    'password=s'=> \$Password,
	    'showcase'=> \$GenerateShowcase,
);

# Part one, clean up old files
# Part one a, clean up old 'shows' files and directories.
my $Start;
my ($stat, $size);

# Change dir and resave with fullpath
chdir("$Maindir") or die "Failed to change to directory $Maindir\n";
chomp($Maindir = `pwd`);

if (! -e $HeadendDir)
{   
    print STDERR "Missing $HeadendDir directory\n";
    print STDERR "Creating...\n";
    mkdir("$HeadendDir") or die "Failed to create directory $HeadendDir\n";
}
else
{
    # remove old headend text files so that the entire dir can be copied/gzipped into the slice directory
    unlink(<$HeadendDir/*-*.txt>);
}

# Part 2, grab new files;
if( $Part eq 2 )
{
    $Start = time();
    my $Quiet = '--quiet';
    if( $Verbose > 1 ) { $Quiet = ''; }
    unlink("$Maindir/datadirect.xml");
    system("$Maindir/datadirect.pl --days $Days --username $Username --password $Password");
    $stat = stat("$Maindir/datadirect.xml");
    if (!defined($stat) || $stat->size == 0) {
        print STDERR "datadirect.pl failure, no output\n";
        exit(1);
    }
    debugprint(0, sprintf("Guide grab) %d sec\n", time() - $Start));
    $Part = 3;
}

# Part 3, process new files;
# Part 3a, process new XML files into Show listings
if( ($Part eq 3) || ($Part eq '3a') )
{
    $Start = time();
    open PROCESSING, "$Maindir/datadirect-parser.pl -verbose $Verbose  2>&1 |";
    while( <PROCESSING> )
    {
        my $Line = $_;
	if( !defined( $ValidTime ) && ($Line =~ /Valid time \[(.*)\]/ ))
	{
	    $ValidTime = $1;
	}
	print $Line;
    }
    close PROCESSING;
    debugprint(0, sprintf("Running datadirect-parser.pl %d sec\n", time() - $Start));
    if (defined($GenerateShowcase))
    {
        $Start = time();
        my $optional_scrapers = DDParserUtils::cfg_val("showcase","optional_scrapers");
        foreach my $scraper (split(',',$optional_scrapers))
        {
            system("$Maindir/$scraper");
        }
	system("$Maindir/importImages.pl");
        system("$Maindir/getRssTvPackageItems.pl");
	system("$Maindir/getLetterboxPackageItems.pl");
	system("$Maindir/getOpenAndShutPackageItems.pl");
        debugprint(0, sprintf("Showcase Scraping %d sec\n", time() - $Start));
    }
    $Part = '3b';
}

if( $Part eq '3b' )
{
    if( defined( $ValidTime ) )
    {
    	$Start = time();
	system("$Maindir/mkPrograms.pl -verbose $Verbose $ValidTime");
        debugprint(0, sprintf("mkPrograms %d sec\n", time() - $Start));
    	$Start = time();
	system("$Maindir/mkHeadends.pl");
        debugprint(0, sprintf("mkHeadends %d sec\n", time() - $Start));
    }

    $Part = '3c';
}

if( $Part eq '3c' )
{
    if (defined($GenerateShowcase))
    {
    	$Start = time();
        system("$Maindir/mkShowcases.pl");
        debugprint(0, sprintf("mkShowcases %d sec\n", time() - $Start));
    }
    $Part = 4;
}

# Part 4, process Show listings into slices
if( $Part eq 4 )
{
    $Start = time();
    slicefiles("$Maindir/$HeadendTextfileDir/", $HeadendDir);
    debugprint(0, sprintf("Process headend into slices %d sec\n", time() - $Start));

    $Start = time();
    slicefiles("$Maindir/$ListingsTextfileDir/", $ListingsDir);
    debugprint(0, sprintf("Process shows into slices %d sec\n", time() - $Start));
    $Part = 5;
}

sub slicefiles($$)
{
    my($sourceDir,$targetDir) = @_;
    my ($FileName, $oldDir);
    chomp($oldDir = `pwd`);

    # Change dir and resave with fullpath
    chdir($sourceDir);
    chomp($sourceDir = `pwd`);

    opendir TEXTFILES, $sourceDir;
    my @Textfiles = grep { /^.+.txt$/ &&
			  ( -M "$sourceDir/$_" < ($ListModTime/24.0))
			} readdir(TEXTFILES);
    debugprint(3, sprintf("%s\n",join(',',@Textfiles)));
    foreach $FileName (@Textfiles)
    {
	my $Slicefile = $FileName;
        $Slicefile =~ s/\.txt/\.slice/;
        debugprint(1, sprintf("Process %s\n", $FileName));
	debugprint(2, sprintf("into %s\n", "$targetDir/$Slicefile"));
	system("$WriteGuide < $sourceDir/$FileName > $targetDir/$Slicefile");
	if ($Gzip) {
		system("gzip --best --force $targetDir/$Slicefile");
		my $suffix = ".gz";
		my $size = stat("$targetDir/$Slicefile$suffix")->size;
		if ($size == 0) {
			print STDERR "gzip failure, no output for $targetDir/$Slicefile\n";
		}
	}
    }

    close TEXTFILES;
    chdir($oldDir);
}

sub debugprint()
{
    my $Debuglvl = shift;
    my $String   = shift;
    if( $Verbose > $Debuglvl )
    {
	print $String;
    }
}
