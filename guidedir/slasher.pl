#!/usr/bin/perl

use strict;
use Net::FTP;
use Net::Telnet;
use Getopt::Long;



my $Days = 10;
my $Maindir = '.';
my $IMDBDIR = undef;
# if you want to use the tv_imdb script, it must be in your path, and define
# the $IMDBDIR variable so that it knows where to look for the files.
#$IMDBDIR='/home/svanderw/imdb/';

my $SliceSubDir = 'slices/';
my $ShowSubDir  = 'shows/';
my $ListSubDir  = 'listings/';
my $ListModTime = 1;

my $TivoIP = 'tivo';
my $NTPHost = '206.42.42.5';
my $TiVoSliceDir = '/var/slice/packages';
my $TiVoScpDir = '/var/slice/';
my $Part = 1;
my $Verbose = 0;
my $Force = 0;

GetOptions( 'days=i' => \$Days,
	    'listmodtime=i' => \$ListModTime,
	    'maindir=s' => \$Maindir,
	    'slicesub=s'=> \$SliceSubDir,
	    'tivoip=s' => \$TivoIP,
	    'tivoslicedir=s' => \$TiVoSliceDir,
	    'tivoscpdir=s'   => \$TiVoScpDir,
	    'part=s'         => \$Part,
	    'ntphost=s'      => \$NTPHost,
	    'verbose+'       => \$Verbose,
	    'v+'             => \$Verbose,
	    'F'              => \$Force,
);

# Part one, clean up old files
# Part one a, clean up old 'shows' files and directories.
my $Start;
if( ($Part eq 1) || ($Part eq '1a'))
{
    $Start = time();
    system "rm -rf $Maindir/$ShowSubDir/*";
    unlink "$Maindir/myLastprogs";
    $Part = '1b';
    debugprint(0, sprintf("Shows cleanup) %d sec\n", time() - $Start));
}
# Part one b, clean up old listings
if( ($Part eq '1b'))
{
    $Start = time();
    if( !defined($Maindir) || ($Maindir =~ /^\s*$/) )
    {
	die "Bad configuration, just prevented total system wipe ;-)\n";
    }
    system "rm -rf $Maindir/$ListSubDir/*.xml $Maindir/$ListSubDir/*.xml.IMDB";
    debugprint(0, sprintf("listings cleanup) %d sec\n", time() - $Start));
    $Part = '1c';
}
# Part one b, clean up old html files
if( ($Part eq '1c'))
{
    $Start = time();
    my @FileList;
    if( $Force )
    {
	debugprint(0, sprintf("Clearing urldata cache\n"));
	system "rm -rf $Maindir/urldata/*";
    } else {
	open FINDLIST, "find $Maindir/urldata/progid/ -name '*.html' -atime +10 |";
	@FileList = <FINDLIST>;
	close FINDLIST;
	my $cleanDays = $Days -2;
	open FINDLIST, "find $Maindir/urldata/[0-9]* -name '*.html' -mtime +$cleanDays |";
	push @FileList, <FINDLIST>;
	close FINDLIST;
	chomp @FileList;
	debugprint(1, sprintf("Unlinking %s\n",join(',',@FileList)));
	unlink @FileList;
    }
    
    debugprint(0, sprintf("urldata cache cleanup) %d sec\n", time() - $Start));
    $Part = '2';
}
# Part 2, grab new files;
if( $Part eq 2 )
{
    $Start = time();
    my $Quiet = '--quiet';
    if( $Verbose > 1 ) { $Quiet = ''; }
    system("tv_grab_na --days $Days $Quiet --listings '$Maindir/$ListSubDir/listings-\%y\%m\%d.xml'");

    debugprint(0, sprintf("Guide grab) %d sec\n", time() - $Start));
    $Part = 3;
}
# Part 3, process new files;
# Part 3a, process new XML files into Show listings
if( ($Part eq 3) || ($Part eq '3a') )
{
    $Start = time();
    my $listfile;
    my $count = 0;
    opendir LISTDIR, "$Maindir/$ListSubDir/";

    my @XmlFiles = grep { /[0-9]\.xml$/ &&
                          ( -M "$Maindir/$ListSubDir/$_" < ($ListModTime/24.0))
			} sort(readdir(LISTDIR));
    debugprint(1, sprintf( "%s\n", join(',',@XmlFiles)));
    close LISTDIR;
    my $Quiet = '--quiet';
    if( $Verbose > 1 ) { $Quiet = ''; }
    foreach $listfile ( @XmlFiles )
    {
	if( defined($IMDBDIR) )
	{
	    system("tv_imdb --imdbdir $IMDBDIR $Quiet --output $Maindir/$ListSubDir/$listfile.IMDB $Maindir/$ListSubDir/$listfile");
	    $listfile.=".IMDB";
	}
	system("$Maindir/parsexmlguide.pl -f $Maindir/$ListSubDir/$listfile");
	$count++;
    }
    closedir LISTDIR;
    debugprint(0, sprintf("Parse XML files(%d)) %d sec\n", $count, time() - $Start));
    $Part = '3b';
}
# Part 3b, process Show listings into slices
our $SliceCnt = 0;
if( $Part eq '3b' )
{
    my $ftpdebug = 0;
    if( $Verbose > 1 ) { $ftpdebug = $Verbose - 1; }

    $Start = time();
    my $ftp = Net::FTP->new($TivoIP, Debug=> $ftpdebug);
    eval { $ftp->login("",""); };
    if ($@) {   die "couldn't open ftp connection to $TivoIP: $@";
		die "Make sure tivoftpd is installed and running and that there are no other active connections to it.\n";
	    }
    $ftp->cwd($TiVoSliceDir);
    $ftp->type("I");

    my $JDay;
    opendir SHOWDIR, "$Maindir/$ShowSubDir/";
    my @ShowDirs = grep { /^([0-9]+)$/ &&
                          ( -M "$Maindir/$ShowSubDir/$_" < ($ListModTime/24.0))
			} readdir(SHOWDIR);
    debugprint(1, sprintf("%s\n",join(',',@ShowDirs)));
    foreach $JDay (@ShowDirs)
    {
	my $Slicefile = "$Maindir/$SliceSubDir/$JDay.slice";
	system("perl -I $Maindir/TiVo $Maindir/mkslice $JDay > $Slicefile");
	$ftp->put($Slicefile);
	$SliceCnt++;
    }
    $ftp->quit;

    close SHOWDIR;
    debugprint(0, sprintf("Process shows into slices and ftp) %d sec\n", time() - $Start));
    $Part = 4;
}
# Part 4: log into TiVo and process the files
if ( $Part eq '4' )
{
    $Start = time();
    my @Lines;
    my $Cmd;
    my $Telnet = Net::Telnet->new( Timeout => 10,
			      );
    $Telnet->open($TivoIP);
    #$Telnet->login("","");
    $Cmd = "ntpdate -b $NTPHost";
    debugprint(1, "$Cmd\n");
    @Lines = $Telnet->cmd(String => $Cmd,);
    debugprint(1,print join("", @Lines));
    $Cmd = "cd $TiVoScpDir";
    debugprint(1, "$Cmd\n");
    @Lines = $Telnet->cmd(String => $Cmd,);
    debugprint(1, join("", @Lines));
    if( $SliceCnt > 0)
    {
	$Cmd = "./do_slice";
	debugprint(1, "$Cmd\n");
	sleep 5;
	@Lines = $Telnet->cmd(String => $Cmd,
			      Timeout => 10000);
	debugprint(1, join("", @Lines));
    } else {
	debugprint(0, "Skipping slice processing, no slices generated\n");
    }


    $Cmd = "./fixup30.tcl";
    debugprint( 1, "$Cmd\n");
    @Lines = $Telnet->cmd(String => $Cmd,
			  Timeout => 10000);
    debugprint(1, join("", @Lines));
    $Cmd = "echo done.";
    debugprint(1, "$Cmd\n");
    @Lines = $Telnet->cmd(String => $Cmd,
			  Timeout => 10);
    debugprint(1, join("", @Lines));
    $Telnet->close;

    debugprint(0, sprintf("TiVo Processing) %d sec\n", time() - $Start));
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
