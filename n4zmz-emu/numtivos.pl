#!/usr/bin/perl
#
# This little utility was written by Warren Toomey.
# Modifications by Dennis Boylan to use the config file.
#
# $Id: numtivos.pl,v 1.2 2004/07/10 23:25:28 n4zmz Exp $

use strict;
use lib '.';
use config;

my($cfg) = new config("tivo.conf");

my($daysago)=$cfg->val("config","defaultdays",14);
$daysago=$ARGV[0] if ($#ARGV==0);

my($count)=0;
my($cutofftime)= time() - 86400 * $daysago;
my($fn) = $cfg->val("config","logfilename");
$fn = $cfg->val("config","statuslog",$fn);

my($call_id);
open(IN, $fn) || die("Can't read logfile\n");
while (<IN>) {
  if (/TCDID=(.+) CALL_ID=(.+) TIME=(\d+)/) {
    $call_id=$2;                             
    $count++ if ($call_id>=$cutofftime);
  }
}
close(IN);
my($s) = ($count > 1 || $count == 0) ? "s" : "";
my($d) = ($daysago > 1 || $daysago == 0) ? "s" : "";
print("$count Tivo$s used the Emulator in the last $daysago day$d\n");
