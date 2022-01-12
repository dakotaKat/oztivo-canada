#!/usr/bin/perl
#
#  $Id: importImages.pl,v 1.2 2004/08/28 22:09:38 pcrane Exp $
#

use strict;

# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use DBI;
use DDParserUtils;
use File::stat;

# Switch to this program's directory
chdir($Bin);

use constant DDPARSER_DSNAME => "SC_ddparser";
use constant DDPARSER_NAME => "ddparser";
use constant SHOWCASE_SEQ => 1;
use constant DDPARSER_BANNER_IMAGE_SUFFIX => "ddparser_smbanner";
use constant DDPARSER_BIGBANNER_IMAGE_SUFFIX => "ddparser_bigbanner";
use constant DDPARSER_ICON_IMAGE_SUFFIX => "ddparser_icon";

our $Database = DDParserUtils::cfg_val("database","name","tvdata");
our $dBUser = DDParserUtils::cfg_val("database","user","dbuser");
our $dBPassword = DDParserUtils::cfg_val("database","password","dbpassword");
my $dbtype = DDParserUtils::cfg_val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

print "****************************************\n";
print "* Starting importImages.pl\n";
print "****************************************\n";

my %GenericSQL;
$GenericSQL{IMAGES}->{SELECT} = $connection->prepare("SELECT * FROM Images WHERE dsname=? AND name=?");
$GenericSQL{IMAGES}->{INSERT} = $connection->prepare("INSERT INTO Images SET dsname=?,name=?,mtime=?");
$GenericSQL{IMAGES}->{UPDATE} = $connection->prepare("UPDATE Images SET image_ver=image_ver+1,mtime=? WHERE dsname=? AND name=?");
$GenericSQL{SHOWCASES}->{SELECT} = $connection->prepare("SELECT * FROM Showcases WHERE dsname=? AND name=?");
$GenericSQL{SHOWCASES}->{UPDATE} = $connection->prepare("UPDATE Showcases SET showcase_ver=showcase_ver+1,banner_image_id=?,bigbanner_image_id=?,icon_image_id=? WHERE dsname=? AND name=?");
$GenericSQL{SHOWCASES}->{INSERT} = $connection->prepare("INSERT IGNORE INTO Showcases SET dsname=?,name=?,banner_image_id=?,bigbanner_image_id=?,icon_image_id=?,seq_num=?");
$GenericSQL{IMAGES}->{SELECT_SUFFIX} = $connection->prepare("SELECT * FROM Images WHERE RIGHT(name,LENGTH(name)-14)=? ORDER BY image_id DESC");

sub getImageID($)
{
    my $imageSuffix = shift;
    my $imageID;
    if ($GenericSQL{IMAGES}->{SELECT_SUFFIX}->execute($imageSuffix))
    {
        my $row;
        if ($row = $GenericSQL{IMAGES}->{SELECT_SUFFIX}->fetchrow_hashref())
        {
            $imageID = $row->{image_id};
        }
        else
        {
            print STDERR "Failed to get the image_id for $imageSuffix\n";
        }
    }
    return $imageID;
}

my $sourceDir = ".\/headend";
my $FileName;
my $row;
opendir TEXTFILES, $sourceDir;
my @Textfiles = grep { /^SC_sc[0-9]+_ddparser_.+$/ } readdir(TEXTFILES);
foreach $FileName (@Textfiles)
{
    if ($GenericSQL{IMAGES}->{SELECT}->execute(DDPARSER_DSNAME, $FileName))
    {
        my $mtime = stat("$sourceDir/$FileName")->mtime;
        if ($GenericSQL{IMAGES}->{SELECT}->rows() > 0)
        {
            if ($GenericSQL{IMAGES}->{SELECT}->fetchrow_hashref()->{mtime} eq $mtime)
            {
                print "Image is up to date [$FileName]\n";
            }
            else
            {
                if (!$GenericSQL{IMAGES}->{UPDATE}->execute($mtime, DDPARSER_DSNAME, $FileName)
                        || ($GenericSQL{IMAGES}->{UPDATE}->rows() == 0) )
                {
                    print STDERR "Failed to update the version for image $FileName\n";
                }
                else
                {
                    print "Image updated [$FileName]\n";
                }
            }
        }
        else
        {
            $GenericSQL{IMAGES}->{INSERT}->execute(DDPARSER_DSNAME, $FileName, $mtime);
            if ($GenericSQL{IMAGES}->{INSERT}->rows() > 0)
            {
                print "Image inserted [$FileName]\n";
            }
            else
            {
                print STDERR "Failed to insert new image [$FileName]\n";
            }
        }
    }
}
close TEXTFILES;

# Make sure the ddparser showcase is updated in the table
my $banner_image_id = getImageID(DDPARSER_BANNER_IMAGE_SUFFIX);
exit(1) if !defined($banner_image_id);

my $bigbanner_image_id = getImageID(DDPARSER_BIGBANNER_IMAGE_SUFFIX);
exit(1) if !defined($bigbanner_image_id);

my $icon_image_id = getImageID(DDPARSER_ICON_IMAGE_SUFFIX);
exit(1) if !defined($icon_image_id);

my $showcase = DDPARSER_DSNAME."|".DDPARSER_NAME;
if ($GenericSQL{SHOWCASES}->{SELECT}->execute(DDPARSER_DSNAME, DDPARSER_NAME))
{
    if ($GenericSQL{SHOWCASES}->{SELECT}->rows() > 0)
    {
        my $row = $GenericSQL{SHOWCASES}->{SELECT}->fetchrow_hashref();
        if (($row->{banner_image_id} eq $banner_image_id)
                && ($row->{bigbanner_image_id} eq $bigbanner_image_id)
                && ($row->{icon_image_id} eq $icon_image_id))
        {
            print "Showcase is up to date [$showcase]\n";
        }
        else
        {
            if (!$GenericSQL{SHOWCASES}->{UPDATE}->execute($banner_image_id, $bigbanner_image_id, $icon_image_id,
                            DDPARSER_DSNAME, DDPARSER_NAME)
                    || ($GenericSQL{SHOWCASES}->{UPDATE}->rows() == 0) )
            {
                print STDERR "Failed to update showcase [$showcase]\n";
            }
            else
            {
                print "Showcase updated [$showcase]\n";
            }
        }
    }
    else
    {
        $GenericSQL{SHOWCASES}->{INSERT}->execute(DDPARSER_DSNAME, DDPARSER_NAME,
                $banner_image_id, $bigbanner_image_id, $icon_image_id, SHOWCASE_SEQ);
        if ($GenericSQL{SHOWCASES}->{INSERT}->rows() > 0)
        {
                print "Showcase inserted [$showcase]\n";
        }
        else
        {
                print STDERR "Failed to insert new showcase [$showcase]\n";
        }
    }
}

