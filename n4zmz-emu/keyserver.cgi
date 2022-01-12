#!/usr/bin/perl

#
#  keyserver.cgi -- Serve up required keys
#
# $Id: keyserver.cgi,v 1.19 2004/09/11 19:05:13 n4zmz Exp $
#

# Valid commands to send from keyserver.cgi
# ADD keyname
# DROP keyname
# NOTE String
# ERROR String


use CGI;
use strict;
use lib '.';
use config;
use debug;

$VERSION = (qw$Revision: 1.19 $)[1];
my($cfg) = new config("tivo.conf");
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file (tivo.conf)\n";
	exit(1);
}

my(@commands,$bh_version,$version);

sub add_bh_key ($) {
	my($str) = @_;
	my($bhkey) = $cfg->val("keys",$str);
	my($add);
	if (!defined($bhkey)) {
		print STDERR "No data for ($str)\n";
	} else {
		$add = "ADD $str-$bh_version,";
		$add .= $bhkey;
		$add .= "\n";
		push @commands,$add;
	}
}

my($line,$myline,$i,@keys,$bht,$bhpub,$bhpriv);
$bht = $bhpub = $bhpriv = 1;
my($TCD_ID);
$line = <STDIN>;
($TCD_ID) = $line =~ /^SN (.+)$/;
$cfg->sn($TCD_ID);
$bh_version = $cfg->val("keyserver","backhaulversion","20000226");
my($logfilename) = $cfg->val("config","logfile");
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
my($killhmo) = $cfg->val("keyserver","killhmokeys",0);
my($today) = time();
$today = int($today/86400);
my($expire,$key,$swversion);
open(STDERR,">>$debuglog") if (defined($debuglog));
debug_header() if ($debug);
print STDERR "...............>STDIN<..................\n" if ($debug);
# Block of data from TiVo ends with END on a line
my(%keyexp) = { MRV=> 1, NAMETABLE=> 1 };
while($line) { 
	print STDERR $line if ($debug);
	last if ($line =~ /^END$/);
	next if ($line eq "");
	if ($line =~ /^SN /) {
		$TCD_ID = $line;
		$TCD_ID =~ s/SN //;
		chomp($TCD_ID);
	} elsif ($line =~ /^SWNAME /) {
		$swversion = $line;
		$swversion =~ s/SWNAME //;
		chomp($swversion);
	} elsif ($line =~ /^KEYRING /) {
		$myline = $line;
		$myline =~ s/KEYRING //;
		(@keys) = split(/\;/,$myline);
		for $i (@keys) {
			if ($i =~ /^software/i) {
				$keyexp{$i} = 0;
			}
			if ($i =~ /^mrv/i || $i =~ /^nametable/i) {
				($key) = $i =~ /(\S+)-/;
				$keyexp{$key} = 0;
				#got an HMO key
				next if ($killhmo == 0);
				($expire) = $i =~ /-(\d+)-\d+$/;
				if ($today > $expire) {
					push @commands,"DROP $i\n";
					$keyexp{$key} = 1;
				}
			}
			if ($i =~ /^aa/i) {
				($key) = $i =~ /^(AA_2-2-100[01])-/;
				$keyexp{$key} = 0;
			}
			next if ($i !~ /^backhaul_/i);
			($version) = $i =~ /-([0-9,A-F]+)$/i;
			push @commands,"DROP $i\n" if ($version ne $bh_version);
			$bht = 0 if ($i =~ /thumb/i);
			$bhpub = 0 if ($i =~ /public/i);
			$bhpriv = 0 if ($i =~ /private/i);
		}
	}
	$line = <STDIN>
}

$query = new CGI;
debug() if ($debug);
my($add);
my($size) = 4;
$expire = $today + $cfg->val("keyserver","expiredays",90);
my($hmoenabled) = $cfg->val("keyserver","hmoenabled",0);
my($s2,$major,$needkeys,@keys);
$s2 = substr($swversion,-3,3);
($major) = $swversion =~ /^(\d+)\./;
if ($major < 4 || $s2 < 100) {
	print STDERR "Disabled HMO support Software version($major) less than 4 or not a Series2($s2)\n";
	$hmoenabled = 0;
	$needkeys = $cfg->val("keyserver","s1keys");
} else {
	$needkeys = $cfg->val("keyserver","s2keys");
}
if ($hmoenabled) {
	my($hmokeys) = $cfg->val("keyserver","hmokeys");
	if (defined($hmokeys) && $hmokeys ne "") {
		$needkeys .= ",".$hmokeys;
	}
}
@keys = split(/,/,$needkeys);
for $i (@keys) {
	$major = $cfg->val("keys",$i);
	next if (!defined($major));
	add_bh_key("BACKHAUL_THUMB") if ($i =~ /thumb/i && $bht);
	add_bh_key("BACKHAUL_PRIVATE") if ($i =~ /private/i && $bhpriv);
	add_bh_key("BACKHAUL_PUBLIC") if ($i =~ /public/i && $bhpub);
	if ($i =~ /^aa/i) {
		$key = $i;
		$key =~ tr /a-z/A-Z/;
		next if (exists($keyexp{$key}) && $keyexp{$key} == 0);
		$add = "ADD $key-$today-30-0-1,".$major;
		$add .= "\n";
		push @commands,$add;
	}
	if ($i =~ /^software/i) {
		$key = $i;
		$key =~ tr /a-z/A-Z/;
		next if (exists($keyexp{$key}) && $keyexp{$key} == 0);
		$add = "ADD $key,".$major;
		$add .= "\n";
		push @commands,$add;
	}
	if ($i =~ /^mrv/i) {
		$key = $i;
		$key =~ tr /a-z/A-Z/;
		next if (exists($keyexp{MRV}) && $keyexp{MRV} == 0);
		my($custid) = $cfg->val("keyserver","customerid");
		$add = "ADD $key-$today-$expire-$custid,".$major;
		$add .= "\n";
		push @commands,$add;
	}
}
if ($#commands != -1) {
	for $i (@commands) {
		$size += length($i);
	}
}
my($header) = $query->header(-type=>'text/plain',-'Content-Length'=>$size);
# fix capitalization.  Lower case length does not work.
$header =~ s/-length/-Length/;
print $header;
print STDERR $header;
if ($#commands != -1) {
	for $i (@commands) {
		print "$i";
		print STDERR "$i" if ($i =~ /DROP/);
	}
}
print "END\n";
close(STDERR) if (defined($debuglog));
