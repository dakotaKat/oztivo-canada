#!/usr/bin/perl
#
#  mercury -- Setup for frequency of remote scheduling check
#
# $Id: mercury.cgi,v 1.7 2004/09/11 17:30:09 n4zmz Exp $

use CGI;
use strict;
use lib '.';
use config;
use debug;

$VERSION = (qw$Revision: 1.7 $)[1];
$CGI::POST_MAX=1024*100;
$CGI::DISABLE_UPLOADS=1;

my($cfg) = new config("tivo.conf");
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file (tivo.conf)\n";
	exit(1);
}

my($line,$tcdid,$callid,$seqno,$swver,$delay);
my($logfilename) = $cfg->val("config","logfile");
$logfilename = $cfg->val("config","statuslog",$logfilename);
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
open(STDERR,">>$debuglog") if (defined($debuglog));
debug_header() if ($debug);
print STDERR "...............>STDIN<..................\n" if ($debug);
while($line = <STDIN>) { 
	print STDERR $line if ($debug);
	next if ($line !~ /TCD_ID=/);
	next if ($line !~ /DELAY/);
	($tcdid,$callid,$seqno,$swver,$delay) = $line =~ /TCD_ID=(.*) CALL_ID=(.*) SEQ_NO=(.*) SW_VER=(.*) DELAY=(\d+)/;
	last;
}

$cfg->sn($tcdid) if (defined($tcdid) && $tcdid ne "");
$query = new CGI;
debug() if ($debug);
$delay = defined($delay) ? $delay : 900;
$delay = $cfg->val("config","mercurydelay",$delay);
my($enable) = $cfg->val("keyserver","hmoenabled",0);
my($resp);
$resp = ($enable == 0) ? "N" : "Y";
print $query->header(-type=>'text/plain');
print "DELAY=$delay ENABLE=$resp CALL=M\n" if ($seqno eq "");
close(STDERR) if (defined($debuglog));
