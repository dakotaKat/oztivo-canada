package debug;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw (

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(debug debug_header $query $VERSION
);

our $VERSION_debug = (qw$Revision: 1.4 $)[1];

our $VERSION;
our $query;

sub debug_header {
	my($program) = $0;
	$program =~ s/\.cgi$//;
	$program =~ s/.*\///;
	my($datestr) = scalar localtime();
	my($ip) = $ENV{'REMOTE_ADDR'};
	$ip = defined($ip) ? $ip : "";
	print STDERR "===============>$program $VERSION<==================\n";
	print STDERR "$program connection from $ip at $datestr\n";
}

sub debug {
	print STDERR "--------------->CGI<------------------\n";
	no strict "subs";
	$query->save(STDERR);
	print STDERR ">>>>>>>>>>>>>>>>HTTP<<<<<<<<<<<<<<<<<<<\n";
	my(@a,$i);
	@a = $query->http();
	for $i (0..$#a) {
		next if ($a[$i] =~ /IDB_TCINFO/); # skipped for security reasons
		print STDERR $a[$i],"=",$query->http($a[$i]),"\n";
	}
	$i = $query->url(-path_info=>1,-query=>1);
	print STDERR "-=-=-=-=-=-=-=>URL PARAMS<=-=-=-=-=-=-=-=-\n";
	@a = $query->url_param();
	for $i (0..$#a) {
		next if ($a[$i] =~ /IDB_TCINFO/); # skipped for security reasons
		print STDERR $a[$i],"=",$query->url_param($a[$i]),"\n";
	}
}

1;
