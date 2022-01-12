#!/usr/bin/perl
#
#  $Id: getRssTvPackageItems.pl,v 1.3 2004/08/28 22:09:38 pcrane Exp $
#

print "****************************************\n";
print "* Starting getRssTvPackageItems.pl\n";
print "****************************************\n";

use strict;
# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use Date::Manip;
use DBI;
use DDParserUtils;
use File::stat;
use FileHandle;
use LWP::Simple;
use POSIX qw(strtod);
use XML::RSS;

use constant DDPARSER_DSNAME => "SC_ddparser";
use constant DDPARSER_NAME => "ddparser";
use constant RSSTV_NAME => "RSS TV";
use constant RSSTV_DESCRIPTION => "Syndication for your PVR";
use constant RSSTV_BANNER_IMAGE_SUFFIX => "ddparser_rsstv";

our $Database = DDParserUtils::cfg_val("database","name","tvdata");
our $dBUser = DDParserUtils::cfg_val("database","user","dbuser");
our $dBPassword = DDParserUtils::cfg_val("database","password","dbpassword");
my $dbtype = DDParserUtils::cfg_val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my $CurrentTime = time();
my $CurrentDay = $CurrentTime / 86400;
$CurrentDay =~ s/\..*$//;
$CurrentTime -= $CurrentDay * 86400;

# only need to update the showcase version if insert package items
my $updatePackage = 0;

my %GenericSQL;
$GenericSQL{PROGRAMS}->{SELECT} = $connection->prepare("SELECT * FROM Programs WHERE program_title=? AND program_subtitle=? AND program_description=?");
$GenericSQL{PROGRAMS}->{SELECT_NOSUB} = $connection->prepare("SELECT * FROM Programs WHERE program_title=? AND program_subtitle IS NULL AND ? IS NULL AND program_description=?");
$GenericSQL{PROGRAMS}->{SELECT_NODESC} = $connection->prepare("SELECT * FROM Programs WHERE program_title=? AND program_subtitle=? AND program_description IS NULL AND ? IS NULL");
$GenericSQL{PROGRAMS}->{SELECT_NOSUB_NODESC} = $connection->prepare("SELECT * FROM Programs WHERE program_title=? AND program_subtitle IS NULL AND ? IS NULL AND program_description IS NULL AND ? IS NULL");
$GenericSQL{STATIONS}->{SELECT} = $connection->prepare("SELECT affiliate,station_id FROM Stations WHERE callsign=?");
$GenericSQL{PACKAGES}->{SELECT} = $connection->prepare("SELECT package_id,banner_image_id FROM Packages WHERE dsname=? AND name=?");
$GenericSQL{PACKAGES}->{CREATE} = $connection->prepare("INSERT INTO Packages SET dsname=?,name=?,description=?,banner_image_id=?,infoballoon=3");
$GenericSQL{PACKAGES}->{UPDATE} = $connection->prepare("UPDATE Packages SET banner_image_id=?,package_ver=package_ver+1 WHERE dsname=? AND name=?");
$GenericSQL{PACKAGEITEMS}->{INSERT} = $connection->prepare("INSERT IGNORE INTO PackageItems SET package_id=?,affiliation=?,description=?,expiration_day=?,expiration_time=?,program_tmsid=?,station_id=?,schedule_day=?,schedule_time=?");
$GenericSQL{SHOWCASES}->{UPDATE} = $connection->prepare("UPDATE Showcases SET showcase_ver=showcase_ver+1 WHERE dsname=? AND name=?");
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

# create new instance of XML::RSS
my $rss = new XML::RSS (version => '1.0');
$rss->add_module(prefix=>"xmlns:tv", uri=>"http://www.grumet.net/rsstv");

# Grab latest RSSTV
my $rsstv_feed = DDParserUtils::cfg_val("showcase","rsstv_feed","http://pvrsoft.com:8080/cgi-bin/rsstv_feed");
my $content = get($rsstv_feed);
die "Could not retrieve $rsstv_feed" unless $content;

$rss->parse($content);

my $titleAttr = $rss->{'channel'}->{'title'};
my $linkAttr = $rss->{'channel'}->{'link'};
my $descriptionAttr = $rss->{'channel'}->{'description'};
my $pubDateAttr = $rss->{'channel'}->{'pubDate'};
my $managingEditorAttr = $rss->{'channel'}->{'managingEditor'};
print STDERR "title: $titleAttr\n";
print STDERR "link: $linkAttr\n";
print STDERR "description: $descriptionAttr\n";
print STDERR "pubDate: $pubDateAttr\n";
print STDERR "managingEditorAttr: $managingEditorAttr\n";

my ($row, $package_id, $banner_image_id);
if ($GenericSQL{PACKAGES}->{SELECT}->execute(DDPARSER_DSNAME, RSSTV_NAME))
{
    $banner_image_id = getImageID(RSSTV_BANNER_IMAGE_SUFFIX);
    exit(1) if !defined($banner_image_id);

    if ($row = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref())
    {
        $package_id = $row->{package_id};
        if ($row->{banner_image_id} ne $banner_image_id)
        {
            # update the image id in the Package record
            $updatePackage = 1;
        }
    }
    else
    {
        if (!$GenericSQL{PACKAGES}->{CREATE}->execute(DDPARSER_DSNAME,RSSTV_NAME,RSSTV_DESCRIPTION,$banner_image_id)
                || ($GenericSQL{PACKAGES}->{CREATE}->rows() == 0) )
        {
            print STDERR "Failed to create the '".RSSTV_NAME."' package\n";
        }
        elsif ($GenericSQL{PACKAGES}->{SELECT}->execute(DDPARSER_DSNAME, RSSTV_NAME))
        {
            if ($row = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref())
            {
                $package_id = $row->{package_id};
            }
        }
    }
}
if (!defined($package_id))
{
    print STDERR "Failed to get the package_id for ".DDPARSER_DSNAME."|".RSSTV_NAME."\n";
    exit(1);
}

foreach my $item (@{$rss->{'items'}})
{
    my $itemTitleAttr = $item->{'title'};
    my $itemDescriptionAttr = $item->{'description'};
    $itemDescriptionAttr =~ /(Recommended by .*$)/;
    my $recommendationInfo = $1;
    $itemDescriptionAttr =~ s/  Recommended by .*$//g;
    my $itemPubDateAttr = $item->{'pubDate'};
    my $itemTvSubtitleAttr = $item->{'http://www.grumet.net/rsstv'}->{'sub-title'};
    my $itemTvChannelAttr = $item->{'http://www.grumet.net/rsstv'}->{'tvchannel'};
    my $itemTvStartAttr = $item->{'http://www.grumet.net/rsstv'}->{'start'};
    my $itemTvStopAttr = $item->{'http://www.grumet.net/rsstv'}->{'stop'};
    my $itemGuidAttr = $item->{guid};

    my $station_id = 0;
    my $affiliate = "";
    $itemTvChannelAttr =~ /^C[0-9]+(.+)$/;
    my $callsign = $1;
    my $timeOffset  = 0;
    if ($GenericSQL{STATIONS}->{SELECT}->execute($callsign))
    {
        if ($row = $GenericSQL{STATIONS}->{SELECT}->fetchrow_hashref())
        {
            $station_id = $row->{station_id};
            $affiliate = $row->{affiliate};
        }
        elsif ($GenericSQL{STATIONS}->{SELECT}->execute($callsign."P"))
        {
            if ($row = $GenericSQL{STATIONS}->{SELECT}->fetchrow_hashref())
            {
                $station_id = $row->{station_id};
                $affiliate = $row->{affiliate};
                $timeOffset = 3*3600; # 3 hour shift to pacific
            }
        }
    }

    my $schedule_time = &UnixDate(&ParseDate($itemTvStartAttr),"%s") + $timeOffset;
    my $schedule_day = $schedule_time / 86400;
    $schedule_day =~ s/\..*$//;
    $schedule_time -= $schedule_day * 86400;

#    print STDERR "\nITEM:\n";
#    print STDERR "\ttitle: $itemTitleAttr\n";
#    print STDERR "\tdescription: '$itemDescriptionAttr'\n";
#    print STDERR "\tpubDate: $itemPubDateAttr\n";
#    print STDERR "\ttvSub-title: $itemTvSubtitleAttr\n";
#    print STDERR "\ttvChannel: $itemTvChannelAttr\n";
#    print STDERR "\ttvStart: $itemTvStartAttr\n";
#    print STDERR "\ttvStop: $itemTvStopAttr\n";
#    print STDERR "\tguid: $itemGuidAttr\n";

    my $stmtHandle;
    if ($itemTvSubtitleAttr eq '')
    {
        if ($itemDescriptionAttr eq '')
        {
            $stmtHandle = $GenericSQL{PROGRAMS}->{SELECT_NOSUB_NODESC};
        } else {
            $stmtHandle = $GenericSQL{PROGRAMS}->{SELECT_NOSUB};
        }
    } else {
        if ($itemDescriptionAttr eq '')
        {
            $stmtHandle = $GenericSQL{PROGRAMS}->{SELECT_NODESC};
        } else {
            $stmtHandle = $GenericSQL{PROGRAMS}->{SELECT};
        }
    }
    if ($stmtHandle->execute($itemTitleAttr, $itemTvSubtitleAttr, $itemDescriptionAttr))
    {
        while ($row = $stmtHandle->fetchrow_hashref())
        {
            print STDERR "\n$row->{program_title}, $row->{program_tmsid}, $affiliate, $station_id [] \n";
            $GenericSQL{PACKAGEITEMS}->{INSERT}->execute($package_id,$affiliate,$recommendationInfo,
                    ($schedule_day+3),$schedule_time,$row->{program_tmsid},$station_id,$schedule_day,$schedule_time);
            if ($GenericSQL{PACKAGEITEMS}->{INSERT}->rows() > 0)
            {
                $updatePackage = 1;
            }
        }
    }
}
if ($updatePackage)
{
    if (!$GenericSQL{PACKAGES}->{UPDATE}->execute($banner_image_id, DDPARSER_DSNAME, RSSTV_NAME)
            || ($GenericSQL{PACKAGES}->{UPDATE}->rows() == 0) )
    {
        print STDERR "Failed to update package ".DDPARSER_DSNAME."|".RSSTV_NAME."\n";
    }
    else
    {
        print STDERR "Updated package ".DDPARSER_DSNAME."|".RSSTV_NAME." with $banner_image_id\n";
    }
    if (!$GenericSQL{SHOWCASES}->{UPDATE}->execute(DDPARSER_DSNAME, DDPARSER_NAME)
            || ($GenericSQL{SHOWCASES}->{UPDATE}->rows() == 0) )
    {
        print STDERR "Failed to update the version for showcase ".DDPARSER_DSNAME."|".DDPARSER_NAME."\n";
    }
}
