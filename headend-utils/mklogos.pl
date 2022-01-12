#!/usr/bin/perl
#
# This generates the logos text file
#
# Copyright 2003,2004,2005 Dennis J. Boylan, dennis@b-lan.com
# released under the GNU GPL v2
#
# $Id: mklogos.pl,v 1.9 2005/01/23 15:44:56 n4zmz Exp $
#

my($version) = "0.5beta";
my($baseimage) = 1_000_000;
my($basegroup) = 1_100_000;
my($baseset) = 1_200_000;
my($baseversion) = 1;

use strict;
use Config::IniFiles 2.37;
use File::stat;

use constant IMAGE_FORMAT_GIF => 1;
use constant IMAGE_FORMAT_PNG => 2;

use constant LOGOSPACE_TIVO => 1;
use constant LOGOSPACE_DIRECTV => 2;

my($bimage,$bgroup,$bversion,$bset,%images_s1p1,%images_s2p2,$cfg,$cfg2);

print STDERR "$0 version $version\n";
if ($#ARGV < 0 || ! -d $ARGV[0]) {
	print STDERR <<USAGE_EOF;
Usage: $0 directory
i.e. $0 logos

Outputs:
	logos.txt text file for your logos

Configuration file sections and options (config.ini)
Section: [base]
	options:
		image		base number for images
		group		base number for logo group
		version		server version number
		set		base number for dataset

USAGE_EOF
	exit(1);
}

if (! -e "config.ini") {
	print STDERR "Missing config.ini file\n";
	print STDERR "Creating...\n";
	open(F,">config.ini");
	print F <<EOFCONFIG;
[base]
version=1
EOFCONFIG
	close(F);
}
my($fn) = "config.ini";
$cfg = new Config::IniFiles(-file=>$fn,-nocase=>1);
if (!defined($cfg)) {
	my($i);
	for $i (0..$#Config::IniFiles::errors) {
		print STDERR $Config::IniFiles::errors[$i],"\n";
	}
	exit(1);
}
$fn = "config-logos.ini";
if (-r $fn) {
	$cfg2 = new Config::IniFiles(-file=>$fn,-nocase=>1);
	if (!defined($cfg2)) {
		my($i);
		for $i (0..$#Config::IniFiles::errors) {
			print STDERR $Config::IniFiles::errors[$i],"\n";
		}
		exit(1);
	}
}
$bversion = $cfg->val("base","version",$baseversion);
$bimage = $cfg->val("base","image",$baseimage);
$bgroup = $cfg->val("base","group",$basegroup);
$bset = $cfg->val("base","set",$baseset);


sub cfg_val ($$;$) {
	my($section,$index,$def) = @_;
	my($ret) = $def;
	if (defined($cfg2)) {
		$ret = $cfg2->val($section,$index,$def);
	}
	$ret = $cfg->val($section,$index,$ret);
	return $ret;
}

sub do_image ($$$) {
	my($name,$size,$dir) = @_;
	my($image,$serverversion,$format);
	my($iname) = $name;
	$iname =~ tr/A-Z/a-z/;
	if ($iname =~ /(.*)\.png$/) {
		$iname = $1;
		$format = IMAGE_FORMAT_PNG;
	} elsif ($iname =~ /(.*)\.gif$/) {
		$iname = $1;
		$format = IMAGE_FORMAT_GIF;
	} else {
		$format = IMAGE_FORMAT_PNG;
	}
	$serverversion = cfg_val($iname,"version",$bversion);
	$image = cfg_val($iname,"serverid",$bimage++);
	if ($iname =~ /s1-p1/) {
		$images_s1p1{$image} = $iname;
	} elsif ($iname =~ /s2-p2/) {
		$images_s2p2{$image} = $iname;
	} else {
		print STDERR "Invalid file name ($name)\n";
	}
	system("cp -f $dir/$name $dir/$iname") if ($iname ne $name);
	print L <<EOF1;
Image/1/$image/$serverversion {
	Name: {$iname}
	Format: $format
	File: File of size 1/$size
}

EOF1
}

sub mklogo_group ($$$$$$) {
	my($hash,$size,$palette,$has2,$section,$s) = @_;
	my($i,$j,$ret,$version,$param);
	$i = 0;
	for $j (keys %{$hash}) {
		$i++;
	}
	if ($i > 0) {
		$version = $cfg->val($section,"version$s",$bversion);
		$ret = $cfg->val($section,"group$s",$bgroup);
		$bgroup++;
		print L <<EOF1;
LogoGroup/1/$ret/$version {
	Size: $size
	Palette: $palette
	LogoSpace: $s
EOF1
		$i = 0;
		$param = "tivoonly";
		$param = "dtvonly" if ($s == LOGOSPACE_DIRECTV);
		for $j (keys %{$hash}) {
			$s = $hash->{$j};
			next if (cfg_val($s,$param,0));
			print L "	Image: Image/1/$j\n";
		}
		for $j (keys %{$hash}) {
			$s = $hash->{$j};
			next if (cfg_val($s,$param,0));
			if (defined($has2)) {
				$s =~ s/-s[12]-p[12]$//;
				print L "	Index: $has2->{$s}\n";
			} else {
				print L "	Index: $i\n";
			}
			$i++;
		}
		print L "}\n";
	}
	return $ret;
}

MAIN: {
	my($name,$size,$i,$j,$tivoday,$dir,$s1p1,$s2p2,%rev,$idx,$s1p1_1,$s2p2_1);
	my(%save_idx);
	$tivoday = time();
	$tivoday = int($tivoday/86400);
	$dir = $ARGV[0];
	open(L,">$dir/logos.txt");
	print L "Guide type=3\n\n";
	opendir(DIR,$dir);
	while ($name = readdir(DIR)) {
		next if ($name =~ /^\./);
		next if ($name !~ /\.png$/i && $name !~ /\.gif$/i && $name !~ /s[12]-p[12]/i);
		next if (! -f "$dir/$name");
		$size = stat("$dir/$name")->size;
		do_image($name,$size,$dir);
	}
	closedir(DIR);
	$i = 0;
	for $j (keys %images_s1p1) {
		$idx = cfg_val($images_s1p1{$j},"index");
		if (defined($idx)) {
			$name = $images_s1p1{$j};
			$name =~ s/-s1-p1$//;
			$dir = $idx-65536;
			$rev{$name} = $dir;
			$save_idx{$dir} = 1;
		}
	}
	for $j (keys %images_s2p2) {
		$name = $images_s2p2{$j};
		$name =~ s/-s2-p2$//;
		if (!exists($rev{$name})) {
			$idx = cfg_val($images_s2p2{$j},"index");
			if (defined($idx)) {
				$dir = $idx-65536;
				$rev{$name} = $dir;
				$save_idx{$dir} = 1;
			}
		}
	}
	for $j (keys %images_s1p1) {
		$name = $images_s1p1{$j};
		$name =~ s/-s1-p1$//;
		if (!exists($rev{$name})) {
			while (exists($save_idx{$i})) {
				$i++;
			}
			$rev{$name} = $i;
			$save_idx{$i} = 1;
		}
	}
	for $j (keys %images_s2p2) {
		$name = $images_s2p2{$j};
		$name =~ s/-s2-p2$//;
		if (!exists($rev{$name})) {
			while (exists($save_idx{$i})) {
				$i++;
			}
			$rev{$name} = $i;
			$save_idx{$i} = 1;
		}
	}
	$s1p1 = mklogo_group (\%images_s1p1,1,1,\%rev,"s1-p1",LOGOSPACE_TIVO);
	$s2p2 = mklogo_group (\%images_s2p2,2,2,\%rev,"s2-p2",LOGOSPACE_TIVO);
	$s1p1_1 = mklogo_group (\%images_s1p1,1,1,\%rev,"s1-p1",LOGOSPACE_DIRECTV);
	$s2p2_1 = mklogo_group (\%images_s2p2,2,2,\%rev,"s2-p2",LOGOSPACE_DIRECTV);
	print L <<EOF2;

DataSet/1/$bset/$bversion {
	Name: {LogoVersion}
EOF2
	print L "	Data: LogoGroup/1/$s1p1\n" if (defined($s1p1));
	print L "	Data: LogoGroup/1/$s2p2\n" if (defined($s2p2));
	print L "	Data: LogoGroup/1/$s1p1_1\n" if (defined($s1p1_1));
	print L "	Data: LogoGroup/1/$s2p2_1\n" if (defined($s2p2_1));
	print L "	Date: $tivoday\n}\n";
	close L;
	$cfg->setval("base","version",++$bversion);
	$cfg->RewriteConfig();
}
