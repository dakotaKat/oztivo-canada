#!/usr/bin/perl
#
#  $Id: DDParserUtils.pm,v 1.3 2004/08/28 22:09:38 pcrane Exp $
#

package DDParserUtils;

use Config::IniFiles 2.37;
use FindBin qw($Bin);
use XML::LibXML;
use XML::LibXML::Common qw(encodeToUTF8);

use strict;
use warnings;
use vars qw($VERSION $AUTOLOAD $revision);

$VERSION = "1.00";

$DDParserUtils::Namespaces = 1;
$DDParserUtils::Debug = 0;

# Switch to this module's directory to find config files
chdir $Bin;

my $CRLF = "\n";

my $fn = "config.ini";
my $cfg = new Config::IniFiles(-file=>$fn,-nocase=>1);
if (!defined($cfg))
{
    my($i);
    for $i (0..$#Config::IniFiles::errors)
    {
        print STDERR $Config::IniFiles::errors[$i],"\n";
    }
    exit(1);
}

my $cfg_stations;
$fn = "config-channels.ini";
if (-r $fn)
{
    $cfg_stations = new Config::IniFiles(-file=>$fn,-nocase=>1);
    if (!defined($cfg_stations))
    {
        my($i);
        for $i (0..$#Config::IniFiles::errors)
	{
            print STDERR $Config::IniFiles::errors[$i],"\n";
        }
    }
}

sub new
{
    my $class = shift;
    my $self = { };
    bless $self;
    return $self;
}

sub cfg_val ($$;$)
{
    my($section,$index,$def) = @_;
    my($ret) = $def;
    if (defined($cfg_stations))
    {
        $ret = $cfg_stations->val($section,$index,$def);
    }
    $ret = $cfg->val($section,$index,$ret);
    return $ret;
}

sub addNoDataStations($)
{
    my $xmlString = shift;
    my $StartTime = time();

    my %lineupStations = getLineupStationsMap();
    if (not keys(%lineupStations))
    {
	print "No stations to add\n";
	return $xmlString;
    }

    my $parser = new XML::LibXML;
    my $tree = $parser->parse_string($xmlString);
    if (! $tree)
    {
	return 0;
    }
    my $doc = $tree->getDocumentElement;

    my @lineupsToUpdate = ();

    my $stationsNode = $doc->getElementsByTagNameNS("urn:TMSWebServices", "stations")->item(0);
    my @lineups = $doc->getElementsByTagNameNS("urn:TMSWebServices", "lineup");

    foreach my $lineup (@lineups)
    {
        my $idAttr = $lineup->getAttribute("id");
        my $nameAttr = $lineup->getAttribute("name");
        my $locationAttr = $lineup->getAttribute("location");
	if (defined($lineupStations{$idAttr}))
        {
            print "Found lineup $idAttr [$nameAttr - $locationAttr] with stations to add\n";
            push @lineupsToUpdate, $lineup;
        }
    }
    foreach my $lineup (@lineupsToUpdate)
    {
        my $lineupIdAttr = $lineup->getAttribute("id");
        my $lineupNameAttr = $lineup->getAttribute("name");
        my $lineupLocationAttr = $lineup->getAttribute("location");
        my @newLineupStations = @{$lineupStations{$lineupIdAttr}};
        foreach my $station (@newLineupStations)
        {
            my $callsign = $station->{callsign};
            my $station_id = $station->{station_id};
            my $channel_num = $station->{channel_num};
            my $name = cfg_val($callsign,"name",$callsign);
            my $affiliate = cfg_val($callsign,"affiliation","");
            print "Adding station $callsign to $lineupNameAttr - $lineupLocationAttr\n";
            addStation($lineup,$stationsNode,$station_id,$channel_num,$callsign,$name,$affiliate);
        }
    }

    $xmlString = $tree->toString;

    my $TotalTime = time() - $StartTime;
    print "Adding stations took $TotalTime secs\n";

    return $xmlString;
}

sub addStation($$$$$$$$)
{
    my ($lineupNode,$stationsNode,$station_id,$channel_num,$callsign,$name,$affiliate) = @_;

    my $newMap = XML::LibXML::Element->new("map");
    $newMap->setAttribute("station", "$station_id");
    $newMap->setAttribute("channel", "$channel_num");
    $lineupNode->appendChild($newMap);
    $lineupNode->appendTextNode($CRLF);

    my $newStation = XML::LibXML::Element->new("station");
    $newStation->setAttribute("id", "$station_id");
    $stationsNode->appendChild($newStation);
    $stationsNode->appendTextNode($CRLF);

    $newStation->appendTextNode($CRLF);

    my $newCallsign = XML::LibXML::Element->new("callSign");
    $newCallsign->appendTextNode(encodeToUTF8("latin1",$callsign));
    $newStation->appendChild($newCallsign);
    $newStation->appendTextNode($CRLF);

    my $newName = XML::LibXML::Element->new("name");
    $newName->appendTextNode(encodeToUTF8("latin1",$name));
    $newStation->appendChild($newName);
    $newStation->appendTextNode($CRLF);

    my $newAffiliate = XML::LibXML::Element->new("affiliate");
    $newAffiliate->appendTextNode(encodeToUTF8("latin1",$affiliate));
    $newStation->appendChild($newAffiliate);
    $newStation->appendTextNode($CRLF);
}

sub getLineupStationsMap()
{
    my %lineupStations;
    $fn = "no_data_stations.ini";
    if (-e $fn)
    {
        my @stations;
        open ADDONS, $fn;
        while(my $Line = <ADDONS>)
        {
	    next if ($Line =~ /^\#/);
	    next if ($Line =~ /^$/);
	    $Line =~ s/\s*$//;
	    my @Info = split(',',$Line);
            my $lineup_id = $Info[0];
            my $callsign = $Info[1];
            my $channel_num = $Info[2];
	    my $station_id;
	    if (defined($Info[3])) {
                $station_id = $Info[3];
            } else {
                $station_id = 2000 + $channel_num;
	    }
	    if (defined($lineupStations{$lineup_id})) {
	        @stations = @{$lineupStations{$lineup_id}};
            } else {
	        @stations = ();
	    }
            push @stations, { callsign => $callsign, station_id => $station_id, channel_num => $channel_num };
	    $lineupStations{$lineup_id} = [ @stations ];
        }
        close ADDONS;
    }
    return %lineupStations;
}

1;
