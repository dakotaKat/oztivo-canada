#!/usr/bin/perl
#
#  $Id: getLetterboxPackageItems.pl,v 1.3 2004/08/28 22:09:38 pcrane Exp $
#

print "****************************************\n";
print "* Starting getLetterboxPackageItems.pl\n";
print "****************************************\n";

use strict;

# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use DBI;
use DDParserUtils;

use constant DDPARSER_DSNAME => "SC_ddparser";
use constant DDPARSER_NAME => "ddparser";
use constant LETTERBOX_NAME => "Letterbox Presentations";
use constant LETTERBOX_DESCRIPTION => "Programs presented in Letterbox format";
use constant LETTERBOX_BANNER_IMAGE_SUFFIX => "ddparser_letterbox";

our $Database = DDParserUtils::cfg_val("database","name","tvdata");
our $dBUser = DDParserUtils::cfg_val("database","user","dbuser");
our $dBPassword = DDParserUtils::cfg_val("database","password","dbpassword");
my $dbtype = DDParserUtils::cfg_val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my $CurrentTime = time();
my $CurrentDay = $CurrentTime / 86400;
$CurrentDay =~ s/\..*$//;
#$CurrentTime -= $CurrentDay * 86400;

# only need to update the showcase version if insert package items
my $updatePackage = 0;

my %GenericSQL;
$GenericSQL{PROGRAMS}->{SELECT_LBOX} = $connection->prepare("SELECT DISTINCT affiliate,Programs.program_tmsid,Programs.program_description,Schedule.station_id,Schedule.schedule_day,Schedule.schedule_time FROM Programs,Stations,Schedule WHERE Schedule.schedule_day>=? AND Programs.program_tmsid=Schedule.program_tmsid AND Stations.station_id=Schedule.station_id AND letterbox=1");
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

my ($row, $package_id, $banner_image_id);
if ($GenericSQL{PACKAGES}->{SELECT}->execute(DDPARSER_DSNAME, LETTERBOX_NAME))
{
    $banner_image_id = getImageID(LETTERBOX_BANNER_IMAGE_SUFFIX);
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
        if (!$GenericSQL{PACKAGES}->{CREATE}->execute(DDPARSER_DSNAME,LETTERBOX_NAME,LETTERBOX_DESCRIPTION,$banner_image_id)
                || ($GenericSQL{PACKAGES}->{CREATE}->rows() == 0) )
        {
            print STDERR "Failed to create the '".LETTERBOX_NAME."' package\n";
        }
        elsif ($GenericSQL{PACKAGES}->{SELECT}->execute(DDPARSER_DSNAME, LETTERBOX_NAME))
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
    print STDERR "Failed to get the package_id for ".DDPARSER_DSNAME."|".LETTERBOX_NAME."\n";
    exit(1);
}

if ($GenericSQL{PROGRAMS}->{SELECT_LBOX}->execute($CurrentDay))
{
    while ($row = $GenericSQL{PROGRAMS}->{SELECT_LBOX}->fetchrow_hashref())
    {
        my $schedule_day = $row->{schedule_day};
        my $description = $row->{program_description};
        $description = "" if (!defined($description));
        $GenericSQL{PACKAGEITEMS}->{INSERT}->execute($package_id,$row->{affiliate},$description,
                ($schedule_day+3),$row->{schedule_time},$row->{program_tmsid},$row->{station_id},$schedule_day,$row->{schedule_time});
        if ($GenericSQL{PACKAGEITEMS}->{INSERT}->rows() > 0)
        {
            $updatePackage = 1;
        }
    }
}
if ($updatePackage)
{
    if (!$GenericSQL{PACKAGES}->{UPDATE}->execute($banner_image_id, DDPARSER_DSNAME, LETTERBOX_NAME)
            || ($GenericSQL{PACKAGES}->{UPDATE}->rows() == 0) )
    {
        print STDERR "Failed to update package ".DDPARSER_DSNAME."|".LETTERBOX_NAME."\n";
    }
    else
    {
        print STDERR "Updated ".DDPARSER_DSNAME."|".LETTERBOX_NAME." with $banner_image_id\n";
    }
    if (!$GenericSQL{SHOWCASES}->{UPDATE}->execute(DDPARSER_DSNAME, DDPARSER_NAME)
            || ($GenericSQL{SHOWCASES}->{UPDATE}->rows() == 0) )
    {
        print STDERR "Failed to update the version for showcase ".DDPARSER_DSNAME."|".DDPARSER_NAME."\n";
    }
}
