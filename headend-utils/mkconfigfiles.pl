#!/usr/bin/perl
#
# This generates the headend text file and the corresponding stations.txt file
# for xmltv2tivo and parsexmlguide.
#
# Copyright 2003-2004 Dennis J. Boylan, dennis@b-lan.com
# released under the GNU GPL v2
#
# $Id: mkconfigfiles.pl,v 1.42 2004/06/19 21:16:40 n4zmz Exp $
#

my($version) = "2.3";
my($basestation) = 1_100_000;
my($baseheadend) = 8_000_000;
my($baselineup) = 8_000_001;
my($basepostal) = 2_000_000;
my($tmsbase) = 1_000;
my($baseversion) = 1;
my($basechannel) = 10_000;
my($basezip) = 2_000;
my($bzip) = 1_000;
my($dtier) = 1;
my(%callsign);
my(%tms);
my(%chktms);
my(%sid);
my(%outchan);
my(@chancall);
my($cfg,$cfg_stations,$cfg_logos);
my($bstation) = $basestation;
my($bchannel);
my($bversion) = $baseversion;
my($bhead) = $baseheadend;
my($blineup);
my($bpostal);
my($btms);
my($dstate) = "TBD";
my($dcountry) = "TBD";
my($dcounty) = "TBD";
my($dzip);
my($dtimezone);
my(@head);
my($pre512) = 0;
my($skip) = 2000;
my($dpostal) = "";
my($fn,$cfgfn,$logofn,$ignore);
my($lineuptype) = 1;
my($initial) = 0;

use strict;
use Config::IniFiles 2.37;

print STDERR "$0 version $version\n";
if ($#ARGV < 0) {
	print STDERR <<USAGE_EOF;
Usage: $0 [-c config-channels.ini] [-s config-slice.ini] [-i] [-l config-logos.ini] <xmltv config file>
i.e. $0 ~/.xmltv/tv_grab_na.conf

The -c default is config-channels.ini
The -s default is config.ini
The -i default is to not ignore case
The -l default is config-logos.ini

Outputs:
	headend.txt text file for your headend
	stations.txt-xmltv stations.txt file for xmltv2tivo
	stations.txt-parsexml stations.txt file for parsexml
or	stations.txt for specific type

Configuration file sections and options (config.ini)
Section: [base]
	options:
		station		base number for stations
		headend		base number for new headend
		postal		base number for postal section
		lineup		base number for lineup
		version		server version number
		tms		base number for psuedo TMSids
		channel		base number for channel offset
		zipcode		base number for zipcode offset

Section: [default]
	options:
		state		default state (2 characters)
		country		default country
		county		default county
		community	default community name
		lineupname	default lineup name
		timezone	TiVo timezone (1=EST)
		lineuptype	Type of lineup
		tier		default channel tier type
		zipcode		default zipcode
		pre512		xmltv is pre 5.12 (0=no, 1=yes);
		conflictskip	Number of entries to increment by to resolve conflicts
		headendcode	how to generate the headend code (zipcode, provider)
		provider	provider name if missing from config file

Section: [stations]
	options:
		format		xmltv | parsexml | both | none

Section: [CALLSIGN]
	options:
		name		name to use for this callsign
		affiliation	affiliation for this callsign
		fccchannelnum	Broadcast channel number
		city		city for this callsign
		zipcode		zipcode for this callsign
		state		state for this callsign
		tmsid		tmsid for this callsign
		serverid	serverid for this callsign
		version		server version for this callsign
		logoindex	logo offset for this callsign
		country		country for this callsign
		tier		tier this callsign should use
		urlparams	URL parameters for Wktivoguide
		logo		name of the logo to use

Section [FN]
	This section allows overriding of the default and base sections on a
	per filename basis.  For overriding the default sections, there is a
	one to one mapping of parameters.  For the base section, the parameters
	are prefixed by "base".  FN is just the file name and no extension or
	directory information.
USAGE_EOF
	exit(1);
}
$fn = "config-channels.ini";
$cfgfn = "config.ini";
$logofn = "config-logos.ini";
$ignore = 1;
while ($ARGV[0] =~ /^-/) {
	if ($ARGV[0] eq "-c") {
		$fn = $ARGV[1];
		shift; shift;
	}
	if ($ARGV[0] eq "-s") {
		$cfgfn = $ARGV[1];
		shift; shift;
	}
	if ($ARGV[0] eq "-i") {
		$ignore = 0;
		shift;
	}
	if ($ARGV[0] eq "-l") {
		$logofn = $ARGV[1];
		shift; shift;
	}
}
if (! -e $cfgfn) {
	print STDERR "Missing $cfgfn file\n";
	print STDERR "Creating...\n";
	open(F,">$cfgfn");
	print F <<EOFCONFIG;
[base]
version=1

[default]
EOFCONFIG
	close(F);
}

$cfg = new Config::IniFiles(-file=>$cfgfn,-nocase=>$ignore);
if (!defined($cfg)) {
	my($i);
	for $i (0..$#Config::IniFiles::errors) {
		print STDERR $Config::IniFiles::errors[$i],"\n";
	}
	exit(1);
}
if (-r $fn) {
	$cfg_stations = new Config::IniFiles(-file=>$fn,-nocase=>$ignore);
	if (!defined($cfg_stations)) {
		my($i);
		for $i (0..$#Config::IniFiles::errors) {
			print STDERR $Config::IniFiles::errors[$i],"\n";
		}
	}
}
if (-r $logofn) {
	$cfg_logos = new Config::IniFiles(-file=>$logofn,-nocase=>$ignore);
	if (!defined($cfg_logos)) {
		my($i);
		for $i (0..$#Config::IniFiles::errors) {
			print STDERR $Config::IniFiles::errors[$i],"\n";
		}
	}
}


sub incr_base {
  my($var,$val) = @_;
  my($new) = cfg_val("base",$var,$val);
  $new += 1000 if ($new eq $val && $initial != 0);
  return $new;
}

sub init_base {
  $bstation = incr_base("station",$bstation);
  $bversion = cfg_val("base","version",$bversion);
  $bhead = incr_base("headend",$bhead);
  $blineup = incr_base("lineup",$baselineup);
  $bpostal = incr_base("postal",$basepostal);
  $btms = incr_base("tms",$tmsbase);
  $bchannel = incr_base("channel",$basechannel);
  $bzip = incr_base("zipcode",$basezip);
  $initial++;
}

sub init_default {
  $dstate = cfg_val("default","state",$dstate);
  $dcountry = cfg_val("default","country",$dcountry);
  $dcounty = cfg_val("default","county",$dcounty);
  $dzip = cfg_val("default","zipcode",$dzip);
  $dtimezone = cfg_val("default","timezone",$dtimezone);
  $dpostal = cfg_val("default","postalcode",$dpostal);
  $pre512 = cfg_val("default","pre512",$pre512);
  $skip = cfg_val("default","conflictskip",$skip);
  $lineuptype = cfg_val("default","lineuptype",$lineuptype);
}

my($t) = ($ARGV == 0) ? "zipcode" : "provider";
my($heopt) = cfg_val("default","headendcode",$t);

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
	if ($section eq "default") {
		$ret = $cfg->val($fn,$index,$ret);
	} elsif ($section eq "base") {
		$ret = $cfg->val($fn,"base$index",$ret);
	}
	return $ret;
}

sub gen_station ($$$$) {
	my($channel,$callsign,$zip,$comm) = @_;
	my($faketms,$new_channel,$serverversion,$name,$state,$usezip);
	my($aff,$city,$country,$logo,$fcc,$logo_name,$dmanum);
	print STDERR "WARNING: No entry for callsign ($callsign)\n" if (!cfg_SectionExists($callsign));
	$new_channel = cfg_val($callsign,"serverid",$bstation + $channel);
	$serverversion = cfg_val($callsign,"version",$bversion);
	$name = cfg_val($callsign,"name",$callsign);
	$state = cfg_val($callsign,"state",$dstate);
	$usezip = cfg_val($callsign,"zipcode",$zip);
	$city = cfg_val($callsign,"city",$comm);
	$aff = cfg_val($callsign,"affiliation","TBD");
	$country = cfg_val($callsign,"country",$dcountry);
	$logo = cfg_val($callsign,"logoindex",65535);
	$dmanum = cfg_val($callsign,"dmanum",0);
	if (defined($cfg_logos)) {
		$logo_name = cfg_val($callsign,"logo");
		if (defined($logo_name)) {
			$logo = $cfg_logos->val($logo_name."-s1-p1","index",$logo);
		}
	}
	$fcc = cfg_val($callsign,"fccchannelnum");
	$faketms = $tms{$callsign};
	while (exists($tms{$faketms}) && $tms{$faketms} ne $callsign) {
	        $tms{$callsign} += 2000;
		$faketms = $tms{$callsign};
	}
	$tms{$faketms} = $callsign;
	$tms{$callsign} = $faketms;
	while (exists($sid{$new_channel}) && $sid{$new_channel} ne $callsign) {
		$new_channel += 2000;
	}
	$sid{$new_channel} = $callsign;
	$sid{"$channel $callsign"} = $new_channel;
	if (exists($outchan{$new_channel})) {
		print STDERR "Skipping channel($callsign) already created\n";
		return;
	} else {
		$outchan{$new_channel} = 1;
	}
	print H <<EOF;
Station/1/$new_channel/$serverversion {
	TmsId: {$faketms}
	Name: {$name}
	CallSign: {$callsign}
	City: {$city}
	State: {$state}
	ZipCode: {$usezip}
	Country: {$country}
EOF
	if ($dmanum != 0) {
		print H "	DmaNum: $dmanum\n";
	}
	if ($logo != 65535) {
		print H "	LogoIndex: $logo\n";
	}
	if ($aff ne "TBD") {
		print H "	Affiliation: {$aff}\n"
	}
	$aff = cfg_val($callsign,"affiliationindex");
	if ($lineuptype == 16) {
		$fcc = $channel if (!defined($fcc));
	}
	print H "	AffiliationIndex: $aff\n" if (defined($aff));
	print H "	FccChannelNum: $fcc\n"
		if (defined($fcc) && !($lineuptype >= 17 && $lineuptype <= 20));
	print H "}\n\n";
}

sub gen_headend ($$$$$$) {
	my($provid,$prov,$comm,$lineupn,$zip,$hindex) = @_;
	my($lineup,$zipoffset,$post,$serverversion,$i,$station);
	my($serverid,$tier,$ctier,$hzip);
	my($tmshid);
	$lineup = $blineup;
	$zipoffset = $bzip;
	$serverversion = $bversion;
	$zip = $dpostal if ( $dpostal ne "");
	$tier = cfg_val("default","tier",$dtier);
	$tmshid = "$dstate$provid";
	if ($heopt eq "zipcode") {
		$tmshid = "$dstate$zip";
	}
	if ($lineuptype >= 17 && $lineuptype <= 20) {
		$hzip = "DBS";
	} else {
		$hzip = $zip;
	}
	# create a cable headend instead of a Broadcast
	if ($lineuptype == 16) {
		$lineuptype = 1;
	}
	print STDERR "TmsHeadendId missing\n" if ($tmshid eq "");
	print STDERR "Currently using ($tmshid) for Headendid\n" if ($tmshid ne "");
	print STDERR "PostalCode missing\n" if ($hzip eq "");
	print STDERR "Name missing\n" if ($prov eq "");
	print STDERR "Lineup Name missing\n" if ($lineupn eq "");
	print H <<EOF;
Headend/1/$bhead/$serverversion {
	TmsHeadendId: {$tmshid}
	State: {$dstate}
	TimeZone: $dtimezone
	CityPostalCode: CityPostalCode/$zipoffset
	PostalCode: {$hzip}
	EncryptionKeys: {199801,1,0x199793}
	EncryptionKeys: {199803,1,0x199795}
	EncryptionKeys: {199806,1,0x199798}
	CommunityName: {$comm}
	CountyName: {$dcounty}
	Location: {$comm}
	Name: {$prov}
	Lineup: Lineup/$lineup
	Subrecord Lineup/$lineup {
		Name: {$lineupn}
		Type: $lineuptype
EOF
	$blineup++;
	$station = $bchannel;
	for $i (@chancall) {
		print H "		Channel: Channel/$station\n";
		$station++
	}
	print H "	}\n";
	$station = $bchannel;
	my($id,$call);
	for $i (@chancall) {
		($id,$call) = split(/\s/,$i);
		$serverid = $sid{$i};
		$ctier = cfg_val($call,"tier",$tier);
		print H "	Subrecord Channel/$station {\n";
		print H "		Number: $id\n";
		print H "		ServiceTier: $ctier\n";
		print H "		Station: Station/1/$serverid\n";
		print H "	}\n";
		$station++;
	}
	print H <<EOF1;
	Subrecord CityPostalCode/$zipoffset {
		PostalCode: {$hzip}
		CommunityName: {$comm}
	}
}
EOF1
	$head[$hindex] = $bhead;
	$bhead += 1000;
	$bchannel += 10000;
	$bzip++;
}

sub gen_postal ($$) {
	my($hindex,$zip) = @_;
	my($i,$post,$serverversion,$hzip);
	$post = $bpostal;
	$serverversion = $bversion;
	$zip = $dpostal if ( $dpostal ne "");
	print H "\nPostalCode/1/$post/$serverversion {\n";
	for $i (0..$hindex-1) {
		print H "	Headend: Headend/1/$head[$i]\n";
	}
	if ($lineuptype >= 17 && $lineuptype <= 20) {
		$hzip = "DBS";
	} else {
		$hzip = $zip;
	}
	print H "\tPostalCode: {$hzip}\n";
	if ($hzip eq "DBS") {
		$hzip = substr($zip,0,2);
		print H "\tLocation: {$hzip}\n";
	}
	print H "}\n\n";
	$bpostal++;
}

sub gen_stationtxt ($$;$) {
	my($param,$provid,$single) = @_;
	my($station,$i,$faketms,$name,$opt, $chan, $call);
	return if ($param eq "none");
	$opt = ".txt";
	$opt .= "-$dstate$provid" if ($#ARGV > 0);
	$opt .= "-$param" if (!defined($single));
	open(S,">stations$opt");
	if ($param eq "xmltv") {
		print S "# XMLTV RFC2838 channel name	Tivo Channel FSID\n";
	} else {
		print S "# Tivo::Stations header # number, callsign, name, serverid, zap2it_id\n";
	}
	for $i (@chancall) {
		($chan, $call) = split(/\s/, $i) ;
		$station = cfg_val($call,"serverid",$bstation + $chan);
		$faketms = $tms{$call};
		$opt = $call;
		$opt =~ tr/A-Z/a-z/;
		$opt = "C$chan$opt.zap2it.com";
		if ($param eq "xmltv") {
			if ($pre512) {
				print S qq!"$chan $call"			$station\n!;
			} else {
				print S qq!"$opt"			$station\n!;
			}
		} else {
			$name = cfg_val($call,"name",$call);
			if ($pre512) {
				print S "$chan,$call,$name,$station,$faketms\n";
			} else {
				print S "$chan,$opt,$name,$station,$faketms\n";
				# number, callsign, name, serverid, zap2it_id
			}
		}
	}
	close(S);
}

MAIN: {
	my($call,$zip,$comm,$chan,$provider,$prov);       
	my($line,$title,$lineupn,$chntms,$hindex);
	my($param) = $cfg->val("stations","format","both");
	open(H,">headend.txt");
	print H "Guide type=3\n\n";
	$hindex = 0;
	while ($fn = $ARGV[$hindex]) {
		open(FN,"<$fn");
		$fn =~ s/\.conf$//;
		$fn =~ s/.*\///;
		init_base();
		init_default();
		@chancall = ();
		while ($line = <FN>) {
			next if ($line =~ /^#/);
			if ($line =~ /^provider:\s(\d+)\s(.*)$/) {	
				$provider = $1;
				$title = $2;
				$title =~ s/^# //;
				($prov,$comm,$lineupn) = split(/\s-\s/,$title);
				if (!defined($lineupn) || (defined($lineupn) && $lineupn eq "")) {
					$lineupn = $comm;
				}
				$comm = cfg_val("default","community",$comm);
				$lineupn = cfg_val("default","lineupname",$lineupn);
			} elsif ($line =~ /^zip code:\s(.*)$/) {
				$zip = $1;
			} elsif ($line =~ /^postal code:\s(.*)$/) {
				$zip = $1;
				$zip =~ s/[A-Za-z]/0/g;
				$zip = substr($zip,0,5);
			} elsif ($line =~ /^channel:\s(\d+)\s(.*)$/) {
				$chan = $1;
				$call = $2;
				$provider = cfg_val("default","provider") if (!defined($provider) || $provider eq "");
				$comm = cfg_val("default","community") if (!defined($comm) || $comm eq "");
				$lineupn = cfg_val("default","lineupname") if (!defined($lineupn) || $lineupn eq "");
				$prov = $provider if (!defined($prov) || $prov eq "");
				if ($call =~ /(.*)\s#\szap22it_id=(.*)/) {
					$call = $1;
					$chntms = $2;
				} else {
					$chntms = cfg_val($call,"tmsid",$btms + $chan);
				}
				$tms{$call} = $chntms;
				push @chancall,$chan . " " . $call;
				$zip = $dzip if (!defined($zip) || (defined($zip) && $zip eq "") || ($dzip ne "TBD"));
				gen_station($chan,$call,$zip,$comm);

			}
		}
		close(FN);
		gen_headend($provider,$prov,$comm,$lineupn,$zip,$hindex);
		if (!defined($param) || (defined($param) && $param eq "both")) {
			gen_stationtxt("xmltv",$provider);
			gen_stationtxt("parsexml",$provider);
		} else {
			gen_stationtxt($param,$provider,1);
		}
		$hindex++;
	}
	$fn = $ARGV[$hindex-1];
	$fn =~ s/\.conf$//;
	$fn =~ s/.*\///;
	gen_postal($hindex,$zip);
	close(H); 
	if (!defined($zip) || $zip eq "TBD") {
		print STDERR "You might want to set zipcode in the config.ini file.\n";
	}
	$cfg->setval("base","version",++$bversion);
	$cfg->RewriteConfig();
}
