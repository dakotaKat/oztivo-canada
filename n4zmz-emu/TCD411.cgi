#!/usr/bin/perl
##
##  TCD411 -- Tivo request new phone dialing information from here
##
# $Id: TCD411.cgi,v 1.15 2004/07/19 15:22:52 n4zmz Exp $

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

$VERSION = (qw$Revision: 1.15 $)[1];
$query = new CGI;

my($TCD_ID) = $query->param("TcdId");
$TCD_ID = defined($TCD_ID) ? $TCD_ID : "000000000000000";
$cfg = new config("tivo.conf",$TCD_ID);
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file(tivo.conf)\n";
	exit(1);
}
my($tivoOSVersion) = $query->param("SwVerName");
$tivoOSVersion = defined($tivoOSVersion) ? $tivoOSVersion : "1.3.0-04-037-000";
my($swmodel) = substr($tivoOSVersion,-3,3);
$cfg->model($swmodel);
$cfg->swversion($tivoOSVersion);
my($areacode) = $query->param("AreaCode");
my($URLBase) = "&".$cfg->val("config","urlbase");
my($urlslicedir) = $cfg->val("config","urlslicedir");
my($urlheaddir) = $cfg->val("config","urlheaddir",$urlslicedir);
my($urlSliceDir) = "$URLBase"."$urlheaddir";
my($slicedir) = $cfg->val("config","slicedir");
my($headdir) = $cfg->val("config","headenddir",$slicedir);
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
open(STDERR,">>$debuglog") if (defined($debuglog));
if ($debug > 0) {
	debug_header();
	debug();
}
my($SW_LIST) = "";
my($objver) = $query->param("ObjVer");
$objver = defined($objver) ? int($objver) : 0;
$usechksum = 0;
my($filetype) = "AC";
if (defined($areacode)) {
	$filetype .= "-".$areacode;
}
$SW_LIST = find_files($headdir,$urlSliceDir,$filetype,$objver);
if ($SW_LIST eq "") {
	$SW_LIST = "OK";
}
my($tollfree) = $cfg->val("config","usetollfree",NOT_AUTHORIZED);
my($tollfreeno) = $cfg->val("config","tollfree");
print STDERR "SW_LIST($SW_LIST)\n";
print $query->header(-type=>"text/plain");
print "ERR_MSG=\n";
print "AREA_CODE_OBJ=$SW_LIST\n";
print "TOLL_FREE_AUTH=$tollfree\n";
print "TOLL_FREE_NUM=$tollfreeno\n";
close(STDERR) if (defined($debuglog));
