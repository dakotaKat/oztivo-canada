#!/usr/bin/perl

# Zap2it(tm) DataDirect(tm) Client
# Author: JRB 
#
#  $Id: datadirect.pl,v 1.5 2004/09/01 16:34:49 dboardman Exp $
#

use FindBin qw($Bin);
use lib $Bin;

use Getopt::Long;
use Time::Piece;
use strict;
use warnings;

use Text::Iconv;

# Switch to this program's directory
chdir($Bin);

#//////////////////////DEFAULT CONFIGURATION VARIABLES//////////////////////////////////////

our $username = "<insert username>"; #insert the username you chose at the subscription management website
our $password = "<insert password>"; #insert the password you chose
our $num_of_days = 3;
our $compression = 1;

#///////////////////////////////////////////////////////////////////////////////////////////

### Values on command line, if provided, overwrite defaults

GetOptions(  	"username=s"    =>      \$username, 
		"password=s"    =>      \$password,
               	"days=s"        =>      \$num_of_days,
               	"compression!"	=>      \$compression
          );

### Time calculation

my $t = gmtime;

our $start = $t->date . "T00:00:00Z"; 
my $e = $t + $num_of_days * 60 * 60 * 24; 
our $end = $e->date . "T00:00:00Z";
### Set username/password for HTTP Digest

sub SOAP::Transport::HTTP::Client::get_basic_credentials { 
    return "$username" => "$password";
  }


### Build SOAP object
our ($soapenv, $xtvddoc);
use SOAP::Lite; 
#+trace => qw(transport);

$soapenv = SOAP::Lite
 -> service('http://datadirect.zap2it.com/datadirect/wsdls/xtvd.wsdl')
 -> outputxml('true')
 -> on_fault( sub { 
	my($soap,$res)=@_; 
	print "SOAP call failed: ". 
	(ref $res ? $res->faultstring : $soap->transport->status)."\n"; 
	exit 1; 
	} );

if ($compression) {
	$xtvddoc = $soapenv
	  -> proxy('http://localhost/', options => {compress_threshold => 10000}, timeout => 820)
	  -> download("<startTime>$start</startTime><endTime>$end</endTime>")
	}
else 	{
	$xtvddoc = $soapenv
	  #-> proxy('http://foobar/', timeout => 420)
	  -> download("<startTime>$start</startTime><endTime>$end</endTime>")
	}

use DDParserUtils;
$xtvddoc = DDParserUtils::addNoDataStations($xtvddoc);
if (! $xtvddoc)
{
    print "Invalid XML document\n";
    exit 1;
}

### Output xtvd document
open OUTFILE, "> datadirect.xml";
binmode OUTFILE, ":utf8" if $] > 5.007;
print OUTFILE $xtvddoc;
close OUTFILE;
__END__

=head1 NAME

datadirect.pl - a sample PERL script to download an XTVD document of personalized television listings from Zap2it(tm) Data Direct's web service.

=head1 DESCRIPTION

This script is designed to be a fully operable client to demonstrate how to access Data Direct using PERL's SOAP::Lite package.

=head1 REQUIREMENTS

You need to have the following packages loaded onto your system before this script will run:

SOAP::Lite [tested on v1.47]
Time::Piece [tested on v1.16]
GetOpt::Long [tested on v2.58]

You also need to have established a subscription and selected your station lineup via the Data Direct website (http://datadirect.zap2it.com)

=head1 INSTALLATION

Set the variables at the top of the script for your chosen username and password (the same as for your subscription). 

=head1 USAGE

Run the script, and the SOAP envelope containing your desired listings will be output, according to the XTVD schema. If, for some reason, you'd like to run the script without the built-in data compression, add the option "--nocompression" to the command line. Likewise, to override the built-in username and password, add "--username=yourusername" or "--password=yourpassword" to the command line.

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2003 by Tribune Media Services, Inc.  This program is free software; you can redistribute it and/or
modify it under the terms of the Perl Artistic License or the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

If you do not have a copy of the GNU General Public License write to the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  
