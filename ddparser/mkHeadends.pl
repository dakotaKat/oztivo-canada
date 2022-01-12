#!/usr/bin/perl
#
#  $Id: mkHeadends.pl,v 1.16 2004/08/28 22:09:38 pcrane Exp $
#

use strict;

use FindBin qw($Bin);

use DBI;
use Data::Dumper;
use Config::IniFiles 2.37;
use POSIX qw(strtod);

# Switch to this program's directory
chdir($Bin);

use constant SERVICETIER_BASIC => 1;
use constant SERVICETIER_EXTENDEDBASIC => 2;
use constant SERVICETIER_PREMIUM => 3;
use constant SERVICETIER_PAYPERVIEW => 4;
use constant SERVICETIER_MUSIC => 5;

use constant TZ_EASTERN => 1;
use constant TZ_CENTRAL => 2;
use constant TZ_MOUNTAIN => 3;
use constant TZ_PACIFIC => 4;
use constant TZ_ALASKA => 5;
use constant TZ_HAWAII => 6;
use constant TZ_GMT => 7;
use constant TZ_GMT_PLUS1 => 8;
use constant TZ_GMT_PLUS2 => 9;
use constant TZ_GMT_PLUS3 => 10;
use constant TZ_GMT_PLUS4 => 11;
use constant TZ_GMT_PLUS5 => 12;
use constant TZ_GMT_PLUS6 => 13;
use constant TZ_GMT_PLUS7 => 14;
use constant TZ_GMT_PLUS8 => 15;
use constant TZ_GMT_PLUS9 => 16;
use constant TZ_GMT_PLUS10 => 17;
use constant TZ_GMT_PLUS11 => 18;
use constant TZ_GMT_PLUS12 => 19;
use constant TZ_GMT_MINUS1 => 20;
use constant TZ_GMT_MINUS2 => 21;
use constant TZ_GMT_MINUS3 => 22;
use constant TZ_GMT_MINUS4 => 23;
use constant TZ_GMT_MINUS11 => 24;
use constant TZ_GMT_MINUS12 => 25;

use constant LINEUPTYPE_LOCALBROADCAST => 1;
use constant LINEUPTYPE_PRIMARYEXTENDEDBASIC => 2;
use constant LINEUPTYPE_DBSBASIC => 17;

my($bversion);

my $CurrentTime = time();
my $CurrentDay = $CurrentTime / 86400;
$CurrentDay =~ s/\..*$//;
$CurrentTime -= $CurrentDay * 86400;

my $HeadendTextfileDir = './headend';

my ($cfg,$cfg_stations,$cfg_logos);

sub cfg_SectionExists ($) {
    my($section) = @_;
    my($ret) = 0;
    if (defined($cfg_stations)) {
        $ret = $cfg_stations->SectionExists($section);
    }
    $ret = $cfg->SectionExists($section) if ($ret == 0);
    return $ret;
} 

sub cfg_val ($$;$) {
    my($section,$index,$def) = @_;
    my($ret) = $def;
    if (defined($cfg_stations)) {
        $ret = $cfg_stations->val($section,$index,$def);
    }
    $ret = $cfg->val($section,$index,$ret);
    return $ret;
}

sub incr_base {
    my($var,$val) = @_;
    my($new) = cfg_val("base",$var,$val);
    $new += 1000 if ($new eq $val);
    return $new;
}

sub init_base {
    $bversion = cfg_val("base","version",$bversion);
}

my $fn = "config.ini";
if (! -e $fn) {
    print STDERR "Missing $fn file\n";
    print STDERR "Creating...\n";
    open(F,">$fn");
    print F <<EOFCONFIG;
[base]
version=1

[default]
community=Toronto
city=Toronto
county=York
state=ON
country=Canada
#location=Toronto
timezone=1
EOFCONFIG
    close(F);
}

$cfg = new Config::IniFiles(-file=>$fn,-nocase=>1);
if (!defined($cfg)) {
    my($i); 
    for $i (0..$#Config::IniFiles::errors) {
        print STDERR $Config::IniFiles::errors[$i],"\n";
    }
    exit(1);
}               
$fn = "config-logos.ini";
if (-r $fn) {
    $cfg_logos = new Config::IniFiles(-file=>$fn,-nocase=>1);
    if (!defined($cfg_logos)) {
        my($i);
        for $i (0..$#Config::IniFiles::errors) {
            print STDERR $Config::IniFiles::errors[$i],"\n";
        }
        exit(1);
    }
}

init_base();

our $Database = $cfg->val("database","name","tvdata");
our $dBUser = $cfg->val("database","user","dbuser");
our $dBPass = $cfg->val("database","password","dbpassword");
my $dbtype = $cfg->val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPass, {printerr=>0} ) or die $DBI::errstr;

my $cfg_Community = cfg_val("default","community","Toronto");
my $cfg_City = cfg_val("default","city","Toronto");
my $cfg_County = cfg_val("default","county","York");
my $cfg_State = cfg_val("default","state","ON");
my $cfg_Country = cfg_val("default","country","Canada");
my $cfg_TimeZone = cfg_val("default","timezone",TZ_EASTERN);

$fn = "config-channels.ini";
if (-r $fn) {
    $cfg_stations = new Config::IniFiles(-file=>$fn,-nocase=>1);
    if (!defined($cfg_stations)) {
        my($i);
        for $i (0..$#Config::IniFiles::errors) {
            print STDERR $Config::IniFiles::errors[$i],"\n";
        }
    }
}

if (! -e $HeadendTextfileDir)
{
    print STDERR "Missing $HeadendTextfileDir directory\n";
    print STDERR "Creating...\n";
    mkdir $HeadendTextfileDir;
}
else
{
    # remove old headend text files so that the entire dir can be copied/gzipped into the slice directory
    unlink(<$HeadendTextfileDir/*-*.txt>);
}

my $UpdateTime= $ARGV[0];
my %GenericSQL;
$GenericSQL{POSTAL}->{SELECT} = $connection->prepare("SELECT DISTINCT tivo_postalcode,postal_location FROM Lineups");
$GenericSQL{LINEUPS}->{SELECT} = $connection->prepare("SELECT * FROM Lineups where tivo_postalcode=? AND postal_location=? ORDER BY lineup_type");
$GenericSQL{LINEUP}->{SELECT} = $connection->prepare("SELECT *,channel_num*1 AS channel_int FROM Lineup_map WHERE lineup_id=? ORDER BY channel_int");
$GenericSQL{STATION}->{SELECT} = $connection->prepare("SELECT * FROM Stations WHERE station_id=? ORDER BY station_tivo_id");
$GenericSQL{POSTALCODE}->{SELECT} = $connection->prepare("SELECT * FROM PostalCodes WHERE tivo_postalcode=? AND postal_location=?");
$GenericSQL{MESSAGES}->{SELECT} = $connection->prepare("SELECT * FROM Messages" );
$GenericSQL{MESSAGES}->{DELETE} = $connection->prepare("DELETE FROM Messages WHERE expiration_day < ?");

my %Lineups;
my %cable_lineups;
my %sat_lineups;

$GenericSQL{POSTAL}->{SELECT}->execute();

my $PostalRow;
my($logo_name,$fccnum,$dmanum,$dmaname);
my($have_cable,$have_dbs,$IsDBS);

while( $PostalRow = $GenericSQL{POSTAL}->{SELECT}->fetchrow_hashref() )
{
    %Lineups = ();
    %cable_lineups = ();
    %sat_lineups = ();

    my $PostalCodeWithLocation = $PostalRow->{tivo_postalcode};
    $PostalCodeWithLocation = $PostalCodeWithLocation.'~'.$PostalRow->{postal_location} if ($PostalRow->{postal_location} ne "");

    my $PostalCodeRow;
    if( $GenericSQL{POSTALCODE}->{SELECT}->execute( $PostalRow->{tivo_postalcode}, $PostalRow->{postal_location} ) ) {
        $PostalCodeRow = $GenericSQL{POSTALCODE}->{SELECT}->fetchrow_hashref();
    }

    if($GenericSQL{LINEUPS}->{SELECT}->execute( $PostalRow->{tivo_postalcode}, $PostalRow->{postal_location} ) )
    {
        my $row;
        while( $row = $GenericSQL{LINEUPS}->{SELECT}->fetchrow_hashref() )
        {
            my %lineup = %{$row};
            $Lineups{$row->{lineup_id}} = \%lineup;
            if( $row->{lineup_type} eq 'Satellite' )
            {
                $sat_lineups{$row->{lineup_id}} = \%lineup;
            } else {
                $cable_lineups{$row->{lineup_id}} = \%lineup;
            }
        }
    }
    $have_cable = join(',',keys(%cable_lineups));
    if ($have_cable ne "") {
        print STDERR "Have cable lineups to do ($have_cable)\n";
    }
    $have_dbs = join(',',keys(%sat_lineups));
    if ($have_dbs ne "") {
        print STDERR "Have satellite lineups to do ($have_dbs)\n";
    }
    foreach $IsDBS ($have_cable, $have_dbs) {
        next if ($IsDBS eq "");
        my $SQL = "SELECT DISTINCT station_tivo_id,Stations.station_id,name,callsign,affiliate,station_ver,channel_num FROM Lineup_map,Stations WHERE Lineup_map.station_id=Stations.station_id AND lineup_id IN ($IsDBS) GROUP BY station_tivo_id,Stations.station_id,name,callsign,affiliate,station_ver";
        my $SQLHandle = $connection->prepare($SQL);
        my ($StationRow,$Filename,$ServiceTier,$city,$state,$usezip,$country,$callsign,$logo,$logo_name);
        if ($IsDBS == $have_dbs)
        {
            $ServiceTier = SERVICETIER_PREMIUM;
        }
        else
        {
            $ServiceTier = SERVICETIER_BASIC;
        }
        $Filename = $PostalCodeWithLocation."-".$PostalCodeRow->{postalcode_ver}.".txt";
        open HEADEND, "> $HeadendTextfileDir/$Filename" or die $_;
        print HEADEND "Guide type=3\n\n";

        $SQLHandle->execute();
        while( $StationRow = $SQLHandle->fetchrow_hashref() )
        {
            $callsign = $StationRow->{callsign};
            print "WARNING: No entry for callsign ($callsign)\n" if (!cfg_SectionExists($callsign));
            $city = cfg_val($callsign,"city",$cfg_City);
            $state = cfg_val($callsign,"state",$cfg_State);
            $usezip = cfg_val($callsign,"zipcode",$PostalRow->{tivo_postalcode});
            $country = cfg_val($callsign,"country",$cfg_Country);
            $logo = cfg_val($callsign,"logoindex",65535);
            if (defined($cfg_logos)) {
                $logo_name = cfg_val($callsign,"logo");
                if (defined($logo_name)) {
                    $logo = $cfg_logos->val($logo_name."-s1-p1","index",$logo);
                }
            }
            print "WARNING: No Logo entry for callsign ($callsign)\n" if ($logo == 65535);
            $fccnum = cfg_val($callsign,"fccchannelnum");
            $dmanum = cfg_val($callsign,"dmanum",0);
            $dmaname = cfg_val("dmaname",$dmanum);

            print HEADEND <<EOREC;
Station/1/$StationRow->{station_tivo_id}/$StationRow->{station_ver} {
	TmsId: {$StationRow->{station_id}}
	Name: {$StationRow->{name}}
	CallSign: {$callsign}
	City: {$city}
	State: {$state}
	ZipCode: {$usezip}
	Country: {$country}
	Affiliation: {$StationRow->{affiliate}}
	DmaNum: $dmanum
EOREC
;
            # channel nums may not be numeric, but tivo only accepts int
            print HEADEND "\tFccChannelNum: $fccnum\n" if (defined($fccnum));
            print HEADEND "\tLogoIndex: $logo\n" if ($logo != 65535);
            print HEADEND "\tDmaName: {$dmaname}\n" if (defined($dmaname));
            print HEADEND "}\n\n";
        }

        foreach my $LineupId ( split(',',$IsDBS) )
        {
            my $HeadendId = 6000000 + $LineupId;
            if( $GenericSQL{LINEUP}->{SELECT}->execute( $LineupId ) )
            {
                my $LineupRow;
                my $StationRow;
                my $Type;
                my $TmsHeadendId;
                my $LineupIdent = 1100000 + $LineupId;
                if( $Lineups{$LineupId}->{lineup_type} eq 'Satellite' )
                {
                    $Type = LINEUPTYPE_DBSBASIC;
                } elsif ( $Lineups{$LineupId}->{lineup_type} eq 'LocalBroadcast' ) {
                    $Type = LINEUPTYPE_LOCALBROADCAST;
                } else {
                    $Type = LINEUPTYPE_PRIMARYEXTENDEDBASIC;
                }
                my $CityPostalCode = 8000000 + $LineupId;
                my $Location = $Lineups{$LineupId}->{lineup_location};
                if ($Lineups{$LineupId}->{lineup_tmsid})
                {
                    $TmsHeadendId = $Lineups{$LineupId}->{lineup_tmsid};
                    $TmsHeadendId =~ s/\:.$//;
                    $TmsHeadendId =~ s/[:\-]//g;
                } else {
                    $TmsHeadendId = "$cfg_State$PostalRow->{tivo_postalcode}$LineupId";
                }
                $HeadendId = $cfg->val($TmsHeadendId,"serverid",$HeadendId);
                print HEADEND <<EOREC
Headend/1/$HeadendId/$Lineups{$LineupId}->{lineup_ver} {
	CommunityName: {$cfg_Community}
EOREC
;
                if ($Type != LINEUPTYPE_LOCALBROADCAST)
                {
                    print HEADEND <<EOREC
	CountyName: {$cfg_County}
	State: {$cfg_State}
	TimeZone: $cfg_TimeZone
EOREC
;
                }
                print HEADEND <<EOREC
	PostalCode: {$PostalRow->{tivo_postalcode}}
	EncryptionKeys: {199806,1,0x199798}
	TmsHeadendId: {$TmsHeadendId}
	Location: {$Location}
	CityPostalCode: CityPostalCode/$CityPostalCode
	Name: {$Lineups{$LineupId}->{lineup_name}}
	Lineup: Lineup/$LineupIdent
	Subrecord Lineup/$LineupIdent {
		Name: {$Lineups{$LineupId}->{lineup_device}}
		Type: $Type
EOREC
;
                while( $LineupRow = $GenericSQL{LINEUP}->{SELECT}->fetchrow_hashref() )
                {
                    if( $GenericSQL{STATION}->{SELECT}->execute( $LineupRow->{station_id} ) &&
                        ($StationRow = $GenericSQL{STATION}->{SELECT}->fetchrow_hashref() ) )
                    {
                        my $ChannelId;
                        $ChannelId = 7100000 + $LineupRow->{channel_num};
                        print HEADEND "\t\tChannel: Channel/$ChannelId\n";
                    }
                }
                print HEADEND "\t}\n";
                $GenericSQL{LINEUP}->{SELECT}->execute( $LineupId );
                while( $LineupRow = $GenericSQL{LINEUP}->{SELECT}->fetchrow_hashref() )
                {
                    if( $GenericSQL{STATION}->{SELECT}->execute( $LineupRow->{station_id} ) &&
                        ($StationRow = $GenericSQL{STATION}->{SELECT}->fetchrow_hashref() ) )
                    {
                        my $ChannelId;
                        $ChannelId = 7100000 + $LineupRow->{channel_num};
                        print HEADEND <<EOREC
	Subrecord Channel/$ChannelId {
		Number: $LineupRow->{channel_num}
		ServiceTier: $ServiceTier
		Station: Station/1/$StationRow->{station_tivo_id}
	}
EOREC
;
                    }
                }
                print HEADEND <<EOREC
	Subrecord CityPostalCode/$CityPostalCode {
		PostalCode: {$PostalRow->{tivo_postalcode}}
		CommunityName: {$cfg_Community}
	}
EOREC
;
                print HEADEND "}\n\n";
            }
        }
        my $PostalCode_tivoid = 9000000 + $PostalCodeRow->{postalcode_id};
        $PostalCode_tivoid = $cfg->val($PostalCodeRow->{tivo_postalcode},"postalcode",$PostalCode_tivoid);
        my $PostalCode_ver = $PostalCodeRow->{postalcode_ver};
        print HEADEND <<EOREC
PostalCode/1/$PostalCode_tivoid/$PostalCode_ver {
	PostalCode: {$PostalRow->{tivo_postalcode}}
EOREC
;
        foreach my $LineupId ( split(',',$IsDBS) )
        {
            my $HeadendId = 6000000 + $LineupId;
            my $TmsHeadendId;
            if ($Lineups{$LineupId}->{lineup_tmsid})
            {
                $TmsHeadendId = $Lineups{$LineupId}->{lineup_tmsid};
                $TmsHeadendId =~ s/\:.$//;
                $TmsHeadendId =~ s/[:\-]//g;
            } else {
                $TmsHeadendId = "$cfg_State$PostalRow->{tivo_postalcode}$LineupId";
            }
            $HeadendId = $cfg->val($TmsHeadendId,"serverid",$HeadendId);
            print HEADEND "\tHeadend: Headend/1/$HeadendId\n";
        }
        print HEADEND "\tLocation: {$PostalRow->{postal_location}}\n" if ($PostalRow->{postal_location} ne "");
        print HEADEND "}\n\n";
        close HEADEND;
    }
}
$cfg->setval("base","version",++$bversion);
$cfg->RewriteConfig();


if( $GenericSQL{MESSAGES}->{SELECT}->execute() )
{
    my $row;
    while( $row = $GenericSQL{MESSAGES}->{SELECT}->fetchrow_hashref() )
    {
        my $TiVoId = $row->{message_id} + 9100000;
	open MESSAGE, "> $HeadendTextfileDir/message-$TiVoId.txt";
        print MESSAGE <<ENDMESSAGE
Guide type=3

MessageItem/1/$TiVoId/1 {
	Subject: {$row->{subject}}
	From: {$row->{sender}}
	FromId: 1
	Body: {$row->{message}}
	Priority: $row->{priority}
	ExpirationDate: $row->{expiration_day}
	DateGenerated: $CurrentDay
	TimeGenerated: $CurrentTime
	MessageFlags: 0
	Deleted: 0
	Destination: $row->{destination}
	DisplayFrequency: 8640000
	PtcmCountRemaining: 1
}

ENDMESSAGE
;
	close MESSAGE;
    }
}

$GenericSQL{MESSAGES}->{DELETE}->execute( $CurrentDay - 1 );
