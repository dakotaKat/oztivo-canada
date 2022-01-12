#!/usr/bin/perl
#
# This utility calculates the logo index values of a logo slice.  It
# will also generate a ini style file to standard error.
#
# Copyright 2004 Dennis J. Boylan dennis@b-lan.com
# release under the GNU GPL v2
#
#  $Id: mklogoindex.pl,v 1.1 2004/01/07 19:24:00 n4zmz Exp $
#

$i = $j = 0;
while ($l = <>) {
	if ($l =~ /Image\/1\/(\d+)\/(\d+)\s*\{/) {
		$cimage = $1;
		$version{$cimage} = $2;
	} elsif ($l =~ /\s*Name\:\s\{([A-Za-z0-9\-\_]+)\}/) {
		next if ($1 eq "LogoVersion");
		$logo{$cimage} = $1;
	} elsif ($l =~ /\s*Image\:\sImage\/1\/(\d+)/) {
		$img{$1} = $i;
		$i++;
	} elsif ($l =~ /\s*Index\:\s(\d+)/) {
		$idx{$j} = $1;
		$j++;
	}
}
%rev = reverse %logo;
for $i (sort keys %rev) {
	$j = $rev{$i};
	print "Image ",$logo{$j}," index=",65536+$idx{$img{$j}}," id=$j\n";
	$i =  lc $logo{$j};
	print STDERR "[$i]\n";
	print STDERR "serverid=$j\n";
	print STDERR "version=",$version{$j},"\n";
	print STDERR "index=",65536+$idx{$img{$j}},"\n";
	print STDERR "\n";
}
