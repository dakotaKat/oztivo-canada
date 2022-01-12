package config;

use strict;
use warnings;

require Exporter;

use Config::IniFiles 2.37;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw (

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = (qw$Revision: 1.6 $)[1];

sub new {
	my($type) = shift;
	my($class) = ref($type) || $type || "Config";
	my($fn,$sn) = @_;
	my($self);
	$self->{version} = $VERSION;
	$self->{sn} = $sn if (defined($sn));
	if (! -e "$fn") {
		print STDERR "Configuration file missing ($fn)\n";
		return undef;
	}
	$self->{filename} = $fn;
	my($cfg) = new Config::IniFiles(-file=>$fn,-nocase=>1);
	if (!defined($cfg)) {
		my($i);
		for $i (0..$#Config::IniFiles::errors) {
			print STDERR $Config::IniFiles::errors[$i],"\n";
		}
		return undef;
	}
	$self->{cfg} = $cfg;
	bless $self,$class;
}

sub sn {
	my($self) = shift;
	my($val) = @_;
	$self->{sn} = $val if (defined($val));
	return $self->{sn};
}

sub model {
	my($self) = shift;
	my($val) = @_;
	$self->{model} = $val if (defined($val));
	return $self->{model};
}

sub swversion {
	my($self) = shift;
	my($val) = @_;
	$self->{swversion} = $val if (defined($val));
	return $self->{swversion};
}

sub cfg {
	my($self) = shift;
	return $self->{cfg};
}

sub val {
	my($self) = shift;
	my($section,$param,$default) = @_;
	my($cfg) = $self->cfg;
	my($ret) = $cfg->val($section,$param,$default);
	if (exists($self->{swversion})) {
		$ret = $cfg->val($self->{swversion},$param,$ret);
	}
	if (exists($self->{model})) {
		$ret = $cfg->val($self->{model},$param,$ret);
	}
	if (exists($self->{sn})) {
		$section =~ tr/A-Z/a-z/;
		if ($section eq "tcd_id") {
			$param = "servicestate";
		}
		if ($section eq "expire") {
			$param = "expire";
		}
		if ($param eq "download") {
			$param = $section;
		}
		$ret = $cfg->val($self->{sn},$param,$ret);
	}
	return $ret;
}

1;
