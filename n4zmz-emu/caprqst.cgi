#!/usr/bin/perl
##
##  caprqst -- Tivo request for any remote scheduling
##
# $Id: caprqst.cgi,v 1.1 2004/09/11 17:11:29 n4zmz Exp $

use CGI;
use strict;
use lib '.';
use config;
use files;
use debug;

use constant NOT_AUTHORIZED => 0;
use constant UPGRADE_AUTH => 1;
use constant TEMP_AUTH => 2;
use constant AUTHORIZED => 3;
use constant REQUEST_DENIED => 4;
use constant UPGRADE_TIMEOUT => 5;

$VERSION = (qw$Revision: 1.1 $)[1];
$query = new CGI;

my($TCD_ID) = $query->http("TCD_ID");
$TCD_ID = defined($TCD_ID) ? $TCD_ID : "140000000000000";
$cfg = new config("tivo.conf",$TCD_ID);
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file(tivo.conf)\n";
	exit(1);
}
my($tivoOSVersion) = $query->http("SW_VER");
$tivoOSVersion = defined($tivoOSVersion) ? $tivoOSVersion : "4.0.1b-02-2-140";
my($swmodel) = substr($tivoOSVersion,-3,3);
$cfg->model($swmodel);
$cfg->swversion($tivoOSVersion);
my($crver) = $query->http("CR_VER");
$crver = defined($crver) ? $crver : 1;
my($callid) = $query->http("CALL_ID");
$callid = defined($callid) ? $callid : time();
my($URLBase) = "&".$cfg->val("config","urlbase");
my($urlslicedir) = $cfg->val("config","urlslicedir");
my($urlSliceDir) = "$URLBase"."$urlslicedir";
my($slicedir) = $cfg->val("config","slicedir");
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
open(STDERR,">>$debuglog") if (defined($debuglog));
if ($debug > 0) {
	debug_header();
	debug();
}
print $query->header(-type=>"text/plain");
my($SW_LIST) = "";
$suffix="";
my($filetype) = "RS-$TCD_ID";
$SW_LIST = find_files($slicedir,$urlSliceDir,$filetype,0);
if ($SW_LIST ne "") {
	print "SEQ_NO=$callid\n";
	$SW_LIST =~ s/^\&//;
	$SW_LIST =~ s/\|$//;
	print "URL=$SW_LIST?noclip\n";
}
close(STDERR) if (defined($debuglog));
