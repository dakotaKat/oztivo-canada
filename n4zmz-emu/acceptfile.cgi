#!/usr/bin/perl
#
#  acceptfile.cgi -- Tivo uploads usage logs to this program
#
# $Id: acceptfile.cgi,v 1.11 2004/07/19 15:22:52 n4zmz Exp $

use CGI;
use strict;
use lib '.';
use config;
use debug;

$VERSION = (qw$Revision: 1.11 $)[1];
my($cfg) = new config("tivo.conf");
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file(tivo.conf)\n";
	exit(1);
}
my($logfilename) = $cfg->val("config","logfile");
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
my($uploaddir) = $cfg->val("upload","directory");
my($plist) = $ENV{'QUERY_STRING'};
open(STDERR,">>$debuglog") if (defined($debuglog));

my($line);

debug_header() if ($debug);
print STDERR "...............>STDIN<..................\n" if ($debug);
my(@param) = split(/\&/,$plist);
# type=.30093.th&pp=.gz.bfg&fn=SPECIFY_TOKEN&an=1&prv=1
open(L,">>$uploaddir/log$param[0]");
while($line = <STDIN>) { 
	print STDERR $line if ($debug);
	print L $line;
}
close(L);

$query = new CGI;
debug() if ($debug);
print $query->header(-type=>'text/plain');
print "Status: ok\n";
close(STDERR) if (defined($debuglog));
