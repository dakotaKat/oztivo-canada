#!/usr/bin/perl
##
##  mlog -- Tivo uploads svclog to this program
##
## This script records the time of the last successful session between a
## Tivo and the Emulator. There are two methods to choose from here: one
## where the storeconnecttime configuration parameter is set to 1, and the
## other where the storeconnecttime configuration parameter is 0 or not
## defined.
##
## If storeconnecttime=1, then the timestamp at the end of the current
## session (as seen by the Emulator) is recorded. There is a small but
## non-zero possibility that the timestamp of a failed session may be
## recorded, which means that a Tivo may miss a new slice. However, if
## there are Tivos in different timezones than the Emulator, this is the
## option that you should use.
##
## If storeconnecttime=0 or not defined, then the Emulator records the
## timestamp that the Tivo reports as the time of the last successful
## session. If the Emulator and all the Tivos are in the same timezone,
## then you should use this option.
##
# $Id: mlog.cgi,v 1.22 2005/01/22 20:21:19 n4zmz Exp $

use CGI;
use File::Flock;
use Compress::Zlib;
use strict;
use lib '.';
use config;
use debug;

$VERSION = (qw$Revision: 1.22 $)[1];
$CGI::POST_MAX=1024*100;
$CGI::DISABLE_UPLOADS=1;

my($cfg) = new config("tivo.conf");
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file (tivo.conf)\n";
	exit(1);
}

# Record the Tivo's TCD_ID and the timestamp of the last session
sub save_timestamp($$$) {
  my ($TCDID,$CALLID,$TIME)= @_;
  my (@loglines,$logline);
  my ($tcdfoundinlog) = 0;
  my($logfilename) = $cfg->val("config","logfile");
  $logfilename = $cfg->val("config","statuslog",$logfilename);

  if (-e $logfilename) {
    open(LOG, $logfilename) || die "Can't read log($logfilename)";
    @loglines = <LOG>;
    close(LOG);
    open(LOG, ">$logfilename") || die "Can't write log($logfilename)";
    # Lock the file so we can write to it exclusively
    lock($logfilename);
    foreach $logline (@loglines) { 
      if ($logline =~ /^TCDID=$TCDID/) {	
        # Update this tivo's last successful call
        print LOG "TCDID=$TCDID CALL_ID=$CALLID TIME=$TIME IP=$ENV{'REMOTE_ADDR'}\n";
        $tcdfoundinlog = 1;
      } else {
        # Echo the line out untouched, it was for a different tivo
        print LOG "$logline";
      }
    }

    if ($tcdfoundinlog == 0) {
      print LOG "TCDID=$TCDID CALL_ID=$CALLID TIME=$TIME\n";
    }
    close(LOG);
    # Let other writers in now
    unlock($logfilename);
  } else {
    # No log file yet, create it
    open(LOG, ">$logfilename") || die "Can't create log($logfilename)";
    # Lock the file so we can write to it exclusively
    lock($logfilename);
    print LOG "TCDID=$TCDID CALL_ID=$CALLID TIME=$TIME\n";
    close(LOG);
    # Let other writers in now
    unlock($logfilename);
  }
}

# A quick comment on the algorithm here. If storeconnecttime=1, we
# find the first "tclient_download...STATUS=New" line, record the
# current time and finish. Otherwise, we first find an "aval file"
# line followed by a "tclient_result...STATUS=Succeeded", record
# the timestamp from the Tivo and finish.
# In both situations $upd is used. If storeconnecttime=1, we only
# record the timestamp when $upd==0, i.e on the first "STATUS=New"
# line. In the other situation, $upd records the existence of the
# "aval file" line before the "STATUS=Succeeded" line.
#
sub check_line ($$$) {
	my($line,$storeconnecttime,$upd) = @_;
	my($TCDID,$CALLID,$TIME,$CODE,$slice);
	if ($storeconnecttime==1) {	# Method 1: record time seen by Emulator
    		if ($line =~ /tclient_download TCD_ID=(.+) CALL_ID=(.+) TIME=(\d+).*STATUS=New/ && ($upd==0)) {
			$TCDID  = $1;
			$CALLID = time();
			$TIME = $3;
			$CODE   = $4;
			$upd = 1;
			save_timestamp($TCDID,$CALLID,$TIME);
		}
	} else {			# Method 2: record time seen by Tivo
		if ($line =~ /aval_file TCD_ID=(.+) CALL_ID=(.+) TIME=(.+) AVAL_ID=(.+) FILE_NAME=(.+).slice.*FILE_STATUS=(.+) SRC=(.+)/) {
			$slice = $5;
			$slice =~ s/\/var\/packages\///;
			$CODE = $6;
			return if ($CODE ne "SUCCESS");
			# Ignore non-program slices
			return if ($slice =~ /^LG-|^IR-|^GN-|^AC-|^AF-|^SC-|^CR-/);
			# Ignore headend slices
			return if ($slice =~ /^DBS~/);
			return if ($slice =~ /^\d+/);
			$upd = 1;
		} elsif ($line =~ /tclient_result TCD_ID=(.+) CALL_ID=(.+) TIME=(.+) STATUS=Succeeded CODE=(.+)/ && $upd) {
			$TCDID  = $1;
			$CALLID = $2;
			$TIME   = $3;
			$CODE   = $4;
			save_timestamp($TCDID,$CALLID,$TIME);
		}
	}
}

### MAIN Program ###
my($line,$TCDID,$upd,$gzip);
binmode(STDIN);
$line = <STDIN>;
($TCDID) = $line =~ /TCD_ID=(.+) CALL/;
if (!defined($TCDID)) {
	($TCDID) = $line =~ /TCD_ID:\s(.+)$/;
}
$cfg->sn($TCDID);
my($debug) = $cfg->val("config","debug",0);
my($debuglog) = $cfg->val("debug","logfile");
my($storeconnecttime) = $cfg->val("config","storeconnecttime",0);
open(STDERR,">>$debuglog") if (defined($debuglog));
debug_header() if ($debug);
print STDERR "...............>STDIN<..................\n" if ($debug);

$upd = 0;
$gzip = 0;
my($gzh) = pack("C*",0x1f,0x8b,8);
my($gzb);
my($outbuf);
while ($line) {
	$gzip = 1 if (substr($line,0,3) == $gzh);
	if ($gzip) {
		$gzb .= $line;
		while ($line = <STDIN>) {
			$gzb .= $line;
		}
		$outbuf = Compress::Zlib::memGunzip($gzb);
		for $line (split(/\r/,$outbuf)) {
			print STDERR $line if ($debug);
			check_line($line,$storeconnecttime,$upd);
		}
		last;
	} else {
		print STDERR $line if ($debug);
		check_line($line,$storeconnecttime,$upd);
		$line = <STDIN>;
	}
}

$query = new CGI;
debug() if ($debug);
print $query->header(-type=>'text/plain');
print "Done.\n";
close(STDERR) if (defined($debuglog));
