#!/usr/bin/perl -w
##
##  HServer --	This processes the tivo call requests, test, daily and guided
##		setup calls are supported.
##
## This is based on Dan's Service Emulator.  Read the readme.txt and readme-djb.txt
##
# $Id: HServer.cgi,v 1.64 2005/01/29 17:06:55 n4zmz Exp $

use CGI;
use File::stat;
use URI::Escape;
use strict;
use lib '.';
use config;
use files;
use debug;

# Taken from /tvlib/tcl/tv/Inc.itcl

# ServerResponse return codes
# Start version 1
use constant TS_SR_ACCEPTED => 1;
use constant TS_SR_DENIED => 2;
use constant TS_SR_UNAVAIL => 3;
use constant TS_SR_ADMIN => 4;
use constant TS_SR_SETUP => 5;
use constant TS_SR_TPING => 6;
use constant TS_SR_TSTRING => 7;
use constant TS_SR_SETUPHEAD => 8;
use constant TS_SR_LOOP => 9;
# End version 1

# Ident reason codes
# Start version 1
use constant TS_ID_REGULAR => 1;
use constant TS_ID_ADMIN => 2;
use constant TS_ID_SETUP => 3;
use constant TS_ID_TPING => 4;
use constant TS_ID_TSTRING => 5;
use constant TS_ID_SETUPHEAD => 6;
use constant TS_ID_LOOP => 7;
use constant TS_ID_411 => 8;
# End Version 1

use constant BACKHAUL_NOCHANGE => -1;
use constant BACKHAUL_NOPRIVATE => 1;
use constant BACKHAUL_PRIVATE => 0;

use constant SIGNALTYPE_ROOFTOP => 1;
use constant SIGNALTYPE_CABLE => 2;
use constant SIGNALTYPE_DBS => 3;
use constant SIGNALTYPE_ATSC => 4;
use constant SIGNALTYPE_CABLEBOX => 5;
use constant SIGNALTYPE_DIRECTV => 6;

use constant SERVICESTATE_UNKNOWN => 0;
use constant SERVICESTATE_NEW => 1;
use constant SERVICESTATE_NOTSETUP => 2;
use constant SERVICESTATE_GOOD => 3;
use constant SERVICESTATE_TEST => 4;
use constant SERVICESTATE_LIFETIME => 5;
use constant SERVICESTATE_PASTDUE => 6;
use constant SERVICESTATE_NEVERSETUP => 7;
use constant SERVICESTATE_CLOSED => 8;
use constant SERVICESTATE_STOLEN => 9;
use constant SERVICESTATE_DEACTIVATED => 10;
use constant SERVICESTATE_EVALUATION => 11;
use constant SERVICESTATE_STOREFRONT => 12;
use constant SERVICESTATE_DECLINED => 13;

$VERSION = (qw$Revision: 1.64 $)[1];

$query = new CGI;
my($TCD_ID) = $query->http("TCD_ID");
$TCD_ID = defined($TCD_ID) ? $TCD_ID : "000000000000000";
$cfg = new config("tivo.conf",$TCD_ID);
if (!defined($cfg)) {
	print STDERR "Invalid or missing configuration file (tivo.conf)\n";
	exit(1);
}
my($tivoOSVersion) = $query->http("SW_VER");
$tivoOSVersion = $query->http("IDB_CUR_SWNAME") if (!defined($tivoOSVersion));
$tivoOSVersion = defined($tivoOSVersion) ? $tivoOSVersion : "1.3.0-04-037-000";
my($swmodel) = substr($tivoOSVersion,-3,3);
$cfg->model($swmodel);
$cfg->swversion($tivoOSVersion);
my($urlbase) = $cfg->val("config","urlbase");
my($URLBase) = '&'.$urlbase;


# Given the TCD_ID, determine the make and
# model of this tivo.
sub find_make_and_model ($) {
	my($TCD) = @_;
	my(@models_s1) = ("Philips","Sony","Thompson","Hughes");
	my(@models) = ("Philips","Sony","RCA","AT\&T","Tivo","Hughes","Toshiba",
		"Pioneer","Samsung");
	my(@cat) = ("Standalone","DirecTiVo","Standalone","PAL","DVD","DVDwriter");
	my($man) = substr($TCD,1,1);
	my($dtv) = substr($TCD,2,1);
	my($s1) = substr($TCD,0,1);
	my($model);
	if ($s1 eq "0") {
		$model = $models_s1[$man];
	} else {
		$model = $models[$man];
	}
	return $model,$s1 eq "0",$dtv eq "1",$cat[$dtv];
}

# Find the upgrade slices for a specific model tivo.
#

sub find_upgrade ($) {
	my($man) = @_;
	my($SW_LIST) = "";
	my($current) = $cfg->val($swmodel,"current","3.0");
	my($updir) = $cfg->val("upgrade",$current);
	my($upurl) = $cfg->val($current,"url");
	my($code) = $cfg->val($current,$man);
	my($url) = "$URLBase"."$upurl";
	return $SW_LIST if (!defined($code));
	$SW_LIST .= find_files($updir,$url,"swsystem-$code",0);
	return $SW_LIST if ($SW_LIST eq "");
	$SW_LIST = "";
	$SW_LIST .= find_files($updir,$url,"GZbin",0);
	$SW_LIST .= find_files($updir,$url,"GZcore",0);
	$SW_LIST .= find_files($updir,$url,"GZetc",0);
	$SW_LIST .= find_files($updir,$url,"GZetccombo",0);
	$SW_LIST .= find_files($updir,$url,"GZhpk",0);
	$SW_LIST .= find_files($updir,$url,"GZkernel",0);
	$SW_LIST .= find_files($updir,$url,"GZlib",0);
	$SW_LIST .= find_files($updir,$url,"GZopt",0);
	$SW_LIST .= find_files($updir,$url,"GZprom",0);
	$SW_LIST .= find_files($updir,$url,"GZsbin",0);
	$SW_LIST .= find_files($updir,$url,"GZtvbin",0);
	$SW_LIST .= find_files($updir,$url,"GZtvlib",0);
	$SW_LIST .= find_files($updir,$url,"swsystem-$code",0);
	$SW_LIST .= find_files($updir,$url,"utils",0);
	return $SW_LIST;
}

my($UPLOADBase) = '@'.$cfg->val("acceptfile","upurlbase",$urlbase);
my($urlslicedir) = $cfg->val("config","urlslicedir");
my($urlSliceDir) = "$URLBase"."$urlslicedir";
my($slicedir) = $cfg->val("config","slicedir");
my($urlheaddir) = "$URLBase".$cfg->val("config","urlheaddir",$urlslicedir);
my($headenddir) = $cfg->val("config","headenddir",$slicedir);
my($logfilename) = $cfg->val("config","logfile");
$logfilename = $cfg->val("config","statuslog",$logfilename);
my($downloadall) = $cfg->val("config","downloadall",0);
my($debug) = $cfg->val("config","debug",0);
my($ntp) = $cfg->val("config","ntpserver","204.176.49.10 204.176.49.11");
my($max_slices) = $cfg->val("config","maxslicedays",5);
my($keepdays) = $cfg->val("config","keepdays",3);
my($upload) = $cfg->val("config","useupload",0);
my($mercury) = $cfg->val("config","usemercury",0);
my($keyserver) = $cfg->val("config","usekeyserver",0);
my($debuglog) = $cfg->val("debug","logfile");
my($slicetype) = $cfg->val("config","slicetype","standard");
my($skiplineups) = $cfg->val("config","skiplineups","0");
open(STDERR,">>$debuglog") if (defined($debuglog));
if ($debug > 0) {
	debug_header();
	debug();
}

# Split a string into a set of numbers and versions.  For example, the
# string "6406306-51|6406288-1|6406290-1|6406292-1" would create an
# array of numbers 6406306,6406288,6406290,6406292 and an array of
# versions 51,1,1,1
#
sub split_version ($$$$$) {
	my($string,$lists,$versions,$remove,$init) = @_;
	return if ((!defined($string) || $string eq "") && (!defined($init) || $init eq ""));
	my($tmp,@temp,@in);
	@in = split(/,/,$init) if (defined($init));
	@temp = split(/\|/,$string);
	foreach $tmp (@temp) {
		if ($tmp =~ /-(\d+)$/) {
			push @{$versions},$1;
		} else {
			push @{$versions},0;
		}
		$tmp =~ s/-(\d+)$//;
		$tmp =~ s/^$remove//;
		push @{$lists},$tmp;
	}
	foreach $tmp (@in) {
		next if ($string =~ /$remove$tmp/);
		push @{$versions},0;
		push @{$lists},$tmp;
	}
}

# Fix for 7.1 where the HTTP parameters now become regular parameters.
#
sub fix_param ($;$) {
	my($p,$def) = @_;
	my($ret) = $query->http($p);
	if (!defined($ret)) {
		$ret = $query->param($p);
		$ret = uri_unescape($ret) if (defined($ret));
	}
	$ret = $def if (!defined($ret) && defined($def));
	return $ret;
}

# Obtain the main HTTP query strings.  If some are undefined,
# set default values: $ReasonCode, $tivoOSVersion.  Log the
# value of IDB_SOURCEPARAMETERS.
#
my($CALL_ID) = $query->http("CALL_ID");
$CALL_ID = defined($CALL_ID) ? $CALL_ID : time();
my($IDB_TIMESTAMP) = fix_param("IDB_TIMESTAMP");
my($IDB_LOCATIONID) = fix_param("IDB_LOCATIONID");
my($IDB_HEADEND) = fix_param("IDB_HEADEND","");
my($IDB_ST_HIST) = fix_param("IDB_ST_HIST","");

my($ReasonCode) = fix_param("IDB_REASONCODE",TS_ID_REGULAR);
my($source) = fix_param("IDB_SOURCEPARAMETERS");
if (defined($source) && $debug > 0) {
	debug_source($source);
}

# Determine the correct signaltype.
#
my($signaltype) = SIGNALTYPE_CABLE;
if (defined($source) && $source =~ /st=1,/) {
	$signaltype = SIGNALTYPE_ROOFTOP;
}

# Determine the correct postalprefix.
#
my($postalprefix) = "00";
my($configp) = fix_param("IDB_CONFIGPARAMETERS");
if (defined($configp) && $configp =~ /zip=(\d+),/) {
	$postalprefix = substr($1,0,2);
}

# Old versions of the TiVo software required a
# special file suffix.
$suffix = "";
my($version);
($version) = $tivoOSVersion =~ /^(\d+\.\d+)/;
if ($version <= 1.3) {
	$suffix = " -t 180";
}

# Add support for 2.0 to change the chksum separator.
#
$chksumsep = "?";
$chksumsep2 = "=";
if ($version < 3.0) {
	$chksumsep = " ";
	$chksumsep2 = "#";
}

# Obtain yet more query parameters.
#
my($upgrade) = 0;
my($SW_LIST) = "";
my($vok) = check_version();
my($man,$s1,$dtv,$type);
($man,$s1,$dtv,$type) = find_make_and_model($TCD_ID);
if ($ReasonCode == TS_ID_REGULAR && !$vok) {
	$SW_LIST .= find_upgrade($man);
	$upgrade++ if ($SW_LIST ne "");
}
my($logo_version) = fix_param("IDB_LOGOVERSION",0);
my($ir_version) = fix_param("IDB_IRDBVERSION",0);
my($af_version) = fix_param("IDB_AFFILIATIONVERSION",0);
my($gn_version) = fix_param("IDB_GENREVERSION",0);
my($mesg_version) = fix_param("IDB_MESSAGE_DESC",0);
$mesg_version =~ s/\|$//;
$mesg_version =~ s/.*\|//;
$mesg_version =~ s/-.*//;
my($showcases,@sclist,@scversion);
$showcases = fix_param("IDB_PREMIUM_SHOWCASES","");

my($menuitems,@milist,@miversion);
$menuitems = fix_param("IDB_MENU_ITEMS","");

my($capture,@crlist,@crversion);
$capture = fix_param("IDB_CAPTURE_REQUESTS","");

my($collab,@cplist,@cpversion);
$collab = fix_param("IDB_COLLAB_DATA","");

my($signed,@silist,@siversion);
$signed = fix_param("IDB_SIGNED_FILES","");

# If running the script from the command line without any of the TiVo
# parameters, set the headend and location to sane values from the
# config file.
#
if (($query->url() =~ /localhost/) && ($IDB_HEADEND eq "") && !$upgrade) {
	my($head) = $cfg->val("slices","headend","ALL");
	$IDB_HEADEND = "$head|ALL";
	$head =~ s/..//;
	$IDB_LOCATIONID = $head."-0" if (!defined($IDB_LOCATIONID));
}

# Determine the location-ids and the versio numbers
# of the location0ids. @locations is the list without
# the version numbers. @lversion is the list of
# version numbers.
#
my($i,@locations,@headends,@lversions);
my($locsuffix) = "";
if (!$upgrade) {
# Special fix for UK TiVos running 2.5
if ($swmodel eq "023" && $version == 2.5) {
	$locsuffix = $cfg->val($swmodel,"headendsuffix","-uk");
}
(@locations) = split(/\|/,$IDB_LOCATIONID);
for $i (0..$#locations) {
	if ($locations[$i] =~ /-(\d+)$/) {
		$lversions[$i] = $1;
	}
	if ($locations[$i] =~ /^DBS-/ && $swmodel eq "023") {
		print STDERR "Converting old UK satellite($locations[$i]) to ";
		#fix UK tivo to support multiple satellite zipcodes
		$locations[$i] = "DBS~".$postalprefix."-".$lversions[$i];
		print STDERR "($locations[$i])\n";
	}
	$locations[$i] =~ s/-[0-9]+//g;
}

# Rebuild the $IDB_LOCATIONID without the version numbers.
#
$IDB_LOCATIONID = join("\|",@locations);

# Rebuild the $IDB_HEADEND without the version numbers.
#
(@headends) = split(/\|/,$IDB_HEADEND);
for $i (0..$#headends) {
	$headends[$i] =~ s/-[0-9]+//g;
}
push @headends,"ALL" if ($IDB_HEADEND !~ /\|ALL/);
$IDB_HEADEND = join("\|",@headends);

# Build version-separated lists for showcase, menuitems,
# capture, collab and signed.
my($x);
$i = $cfg->val("showcases","download");
$x = $cfg->val("showcases","sc$swmodel");
if (defined($i) && ($i ne "")) {
	$i .= ",".$x if (defined($x));
} else {
	$i = $x if (defined($x));
}
split_version($showcases,\@sclist,\@scversion,"SC_",$i);
$i = $cfg->val("menuitems","download");
$x = $cfg->val("menuitem","mi$swmodel");
if (defined($i) && ($i ne "")) {
	$i .= ",".$x if (defined($x));
} else {
	$i = $x if (defined($x));
}
split_version($menuitems,\@milist,\@miversion,"MI_",$i);
$i = $cfg->val("cr","download");
$x = $cfg->val("cr","cr$swmodel");
if (defined($i) && ($i ne "")) {
	$i .= ",".$x if (defined($x));
} else {
	$i = $x if (defined($x));
}
split_version($capture,\@crlist,\@crversion,"CR_",$i);
$i = $cfg->val("cp","download");
$x = $cfg->val("cp","cp$swmodel");
if (defined($i) && ($i ne "")) {
	$i .= ",".$x if (defined($x));
} else {
	$i = $x if (defined($x));
}
split_version($collab,\@cplist,\@cpversion,"CP_",$i);
$i = $cfg->val("si","download");
$x = $cfg->val("si","si$swmodel");
if (defined($i) && ($i ne "")) {
	$i .= ",".$x if (defined($x));
} else {
	$i = $x if (defined($x));
}
split_version($signed,\@silist,\@siversion,"SI_",$i);
}

# Determine if the tivo wants us to use checksums.  Versions prior to 4.0
# will ask but not require it.
$usechksum = fix_param("IDB_USECHKSUMS",1);
if ($version <= 1.3) {
	$usechksum = 0;
}


# Determine the timezone offset for the tivo.
#
my($tzoffset) = $cfg->val("config","needtzoffset",0);
if ($tzoffset != 0) {
	$tzoffset = fix_param("IDB_TZ_OFFSET");
	if (!defined($tzoffset)) {
		$tzoffset = time() - $CALL_ID;
		$tzoffset = int($tzoffset/900)*900;
	print STDERR "Setting TZOFFSET to ($tzoffset)\n";
	}
}
print $query->header(-type=>'text/plain');

# Output debugging information about the tivo's
# signaltype and connection.
sub debug_source {
	my($s) = @_;
	my(@b) = split(/\;/,$s);
	my($i,@c,$j,$param,$val);
	my(@signaltype) = ("unknown","Antenna","Cable","Satellite","ATSC","Cable Box","DIRECTV");
	my(@conn) = ("unknown","RF-In","RF-Out","Composite-In","Composite-Out","Svideo-In","Svideo-Out","Scart-In","Scart-Out");
	my(@aud) = ("unknown","Main","SAP","Mono");
	for $i (@b) {
		(@c) = split(/,/,$i);
		for $j (@c) {
			($param,$val) = split(/=/,$j);
			next if (!defined($val) || $val eq "");
			if ($param eq "st") {
				print STDERR "Using signaltype($val) ",$signaltype[$val],"\n";
			}
			if ($param eq "con") {
				print STDERR "Using connector($val) ",$conn[$val],"\n";
			}
			if ($param eq "as") {
				print STDERR "Using audio source($val) ",$aud[$val],"\n";
			}
			if ($param eq "dar") {
				print STDERR "Using disable auto record($val)\n";
			}
		}
	}
}

# Generate the full URL with checksum, noload and include signature
# file if required.
sub add_file_with_sig ($$$) {
	my($dir,$url,$file) = @_;
	my($ret) = "";
	return $ret if (!-r "$dir/$file");
	$ret = add_chksum($dir,$url,$file,1);
	return $ret if (!$usechksum || !-r "$dir/${file}.sig");
	$ret .= add_chksum($dir,$url,"${file}.sig",1);
	return $ret;
}

sub find_xx_files ($$;$$) {
	my($fn,$version,$last,$all) = @_;
	return find_files($headenddir,$urlheaddir,$fn,$version,$last,$all);
}

# Find slice files by using the daynumbers
# encoded in the files, not by last modification time.
sub find_slice_files2 ($) {
  my($lastdownloadtime) = @_;
  my($SW_LIST) = "";
  my($file,$modtime,$short,$lineup,$startday,$endday);
  my(%headend,$h,$id,$day,$version);
  my($now) = time();

  # Delete slice files whose most recent data is keep days ago or older
  my($deletefilesbefore) = int($now / 86400 ) - $keepdays;

  # Build a list of headend ids and the highest daynumber
  # and version for each headend id
  foreach $h (split(/\|/, $IDB_ST_HIST)) {
    $id= $h; $id=~ s/:.*//;
    $day= $h; $day=~ s/.*[,:]//; $day=~ s/-.*//;
    $version= $h; $version=~ s/.*-//;
    $headend{$id}{day}= $day;
    $headend{$id}{version}= $version;
    print STDERR "FSF2 found $id: $day-$version\n";
  }

  if(!exists($CACHE{$slicedir}) || $CACHE{$slicedir} != 1) {
	  initialize_filecache($slicedir);
  }

  foreach $file (@{$FILES{$slicedir}}) {
    next if (! -r "$slicedir/$file");
    if ($file =~ /\.slice(.gz)?$/i || $file =~ /\.snow(.bnd)?$/i) {

      # Delete slice file if it is more than maxslice days old
      $modtime = stat("$slicedir/$file")->mtime;
      if ($modtime <= $now - ($max_slices * 86400)) {
	unlink("$slicedir/$file"); next;
      }

      # Determine the lineup from the file name
      $short = $file;
      $short =~ s/\.slice(.gz)?$//;
      $short =~ s/\.snow(.bnd)?$//;
      $lineup = $short;
      $lineup =~ s/\_.*//;
      #print STDERR "FSF2 found lineup $lineup\n";

      # Skip if user is not subscribed to this lineup
      next if (!$downloadall && !($lineup =~ $IDB_HEADEND));

      # Determine the startday (if any) and the endday from the file name
      $startday = $short;
      $startday =~ s/(^.+_)//;
      $startday =~ s/(-.*$)//;
      if ($short =~ /-/) {
	$endday = $short;
	$endday =~ s/^.+-//;
      } else {
	$endday = $startday;
      }

      if ($endday > 0) {
	# Delete slice file if it is older than $deletefilesbefore
	if ($endday < $deletefilesbefore) {
	  unlink("$slicedir/$file"); next;
	}

	# Advertise this file if it has an endday > the endday
	# in the TiVo's IDB_ST_HIST
	if (!defined($headend{$id}{day}) || ($endday>$headend{$id}{day})) {
	  $SW_LIST .= add_chksum($slicedir,$urlSliceDir,$file);
	  print STDERR "FSF2 advertising $file\n";
	} else {
   	  print STDERR "FSF2 not advertising $file: daynumber " .
		"$endday <= $headend{$id}{day}\n";
	}
      } else {
	print STDERR "Invalid endday on $file in find_slice_files\n";
      }
    }
  }
  return $SW_LIST;
}

sub find_genre {
	my($version,$lastdownloadtime) = @_;
	my($i);
	my($SW_LIST) = "";
	if ($cfg->val("ignore","genreversion","0") == 1) {
		$SW_LIST .= find_xx_files("GN",$version);
	} else {
		$SW_LIST .= find_xx_files("GN",$version,$lastdownloadtime);
	}
	if ($SW_LIST ne "") {
		$SW_LIST .= add_file_with_sig($headenddir,$urlheaddir,"RM-RemoveObsoleteGenres.runme");
	} elsif (defined($version) && ($version eq "51")) {
		$SW_LIST .= add_file_with_sig($headenddir,$urlheaddir,"RM-addSeriesThumbs.runme");
	}
	return $SW_LIST;
}

sub read_log {
	my($last,$logline,$logfilename);
	$logfilename = $cfg->val("config","logfile");
	$logfilename = $cfg->val("config","statuslog",$logfilename);
	if (!defined($logfilename) ||
	   (!-e "$logfilename") ||
	   (-e "$logfilename" && !-r "$logfilename") || 
	   (-e "$logfilename" && !-w "$logfilename")) {
		print STDERR "Misconfiguration of STATUSLOG ($logfilename)";
		if (!-e "$logfilename") {
			print STDERR " does not exist";
		} else {
			print STDERR " not readable" if (!-r "$logfilename");
			print STDERR " not writeable" if (!-w "$logfilename");
		}
		print STDERR "\n";
	}
	$last = 0;
	open(LOG,$logfilename);
	while ($logline = <LOG>) {
		if ($logline =~ /TCDID=$TCD_ID CALL_ID=(.+) TIME=(\d+)/) {
			#using call ID instead of time because call_id = the starting time of call
			#don't send files there were being created while call is in progress
			#just a safety precaution
			$last = $1 - $tzoffset;
		}
	}
	close(LOG);
	print STDERR "For $TCD_ID returning $last ". scalar localtime($last) . "\n";
	return $last;
}

sub check_version  {
	my($vok) = 1;
	my($skipupg) = $cfg->val("config","skipupgrade",0);
	return $vok if ($skipupg);
	my($current) = $cfg->val($swmodel,"current","3.0");
	if (defined($current)) {
		my($ver);
		($ver) = $tivoOSVersion =~ /(\d+\.\d+)/;
		$vok = 0 if ($ver < $current);
	}
	return $vok;
}

MAIN: {
	my($man1,$s11,$dtv1,$type1);
	if ($TCD_ID ne "" && $debug > 0) {
		print STDERR "Working with a $man $type Series ";
		print STDERR $s1==0? "2 " : "1 ";
		print STDERR "\n";
		($man1,$s11,$dtv1,$type1) = find_make_and_model($swmodel);
		print STDERR "Working with software for a $man1 $type1 Series ";
		print STDERR $s11==0? "2 " : "1 ";
		print STDERR "\n";
		print STDERR "MORON detected\n" if ($man ne $man1);

	}
	my($lastdownloadtime) = 0;
	if ($ReasonCode == TS_ID_REGULAR && !$upgrade) {
		$lastdownloadtime = read_log();
	}
	if ($ReasonCode == TS_ID_REGULAR && !$upgrade) {
		$SW_LIST .= find_xx_files("message",$mesg_version,$lastdownloadtime,1);
	}
	if ($ReasonCode == TS_ID_REGULAR || $ReasonCode == TS_ID_SETUP ||
	    $ReasonCode == TS_ID_SETUPHEAD) {
		if ($cfg->val("ignore","irdbversion","0") == 1) {
			$SW_LIST .= find_xx_files("IR",$ir_version);
		} else {
			$SW_LIST .= find_xx_files("IR",$ir_version,$lastdownloadtime);
		}
		if ($cfg->val("ignore","logoversion","0") == 1) {
			$SW_LIST .= find_xx_files("LG",$logo_version);
		} else {
			$SW_LIST .= find_xx_files("LG",$logo_version,$lastdownloadtime);
		}
		if ($cfg->val("ignore","affiliationversion","0") == 1) {
			$SW_LIST .= find_xx_files("AF",$af_version);
		} else {
			$SW_LIST .= find_xx_files("AF",$af_version,$lastdownloadtime);
		}
		if ($skiplineups) {
			print STDERR "**** skip lineups is turned on\n";
		}
		if (!$upgrade) {
			$SW_LIST .= find_genre($gn_version,$lastdownloadtime);
			for $i (0..$#locations) {
				# Skip zipcode entry if using Antenna for regular call
				next if ($skiplineups || ($ReasonCode == TS_ID_REGULAR && $signaltype == SIGNALTYPE_ROOFTOP && $locations[$i] =~ /^\d+$/));
				$SW_LIST .= find_xx_files($locations[$i].$locsuffix,$lversions[$i],$lastdownloadtime);
			}
			for $i (0..$#sclist) {
				$SW_LIST .= find_xx_files("SC-".$sclist[$i],$scversion[$i],$lastdownloadtime);
			}
			for $i (0..$#milist) {
				$SW_LIST .= find_xx_files("MI-".$milist[$i],$miversion[$i],$lastdownloadtime);
			}
			for $i (0..$#crlist) {
				$SW_LIST .= find_xx_files("CR-".$crlist[$i],$crversion[$i],$lastdownloadtime);
			}
			for $i (0..$#cplist) {
				$SW_LIST .= find_xx_files("CP-".$cplist[$i],$cpversion[$i],$lastdownloadtime);
			}
			for $i (0..$#silist) {
				$SW_LIST .= find_xx_files("SI-".$silist[$i],$siversion[$i],$lastdownloadtime);
			}
		}
	}
	if ($ReasonCode == TS_ID_REGULAR || $ReasonCode == TS_ID_SETUP) {
		$SW_LIST .= find_slice_files2($lastdownloadtime) if (!$upgrade && !$dtv);
	}

	if ($upload && $ReasonCode == TS_ID_REGULAR && !$upgrade) {
		$SW_LIST .= add_file_with_sig($headenddir,$urlheaddir,"RM-cleanThumb.runme");
	}

	if ($SW_LIST eq "") {
		$SW_LIST = "NONE";
	}

	my($Server_Response_Code) = TS_SR_ACCEPTED;
	if ($ReasonCode == TS_ID_SETUPHEAD) {
		$Server_Response_Code = TS_SR_SETUPHEAD;
	} elsif ($ReasonCode == TS_ID_SETUP) {
		$Server_Response_Code = TS_SR_SETUP;
	}

	# force mercury off if performing an upgrade
	$mercury = 0 if ($upgrade || $s1 == 1);

	print STDERR "SW_LIST=($SW_LIST)\n";
	print "ERR_MSG=\n";
	print "VERSION=";
	if (!$upgrade) {
		print "3";
	} else {
		# Magic trick to force a pending restart.
		if ($version <= 3.0) {
			print "3";
		} else {
			print "1";
		}
	}
	print "\n";
	print "CODE=$Server_Response_Code\n";
	print "SW_LIST=$SW_LIST\n";
	print "BACK_CH_PRV=";
	if ($upload && $ReasonCode == TS_ID_REGULAR) {
		print $UPLOADBase."tivo-service/acceptfile.cgi";
		print "\%3Ftype\%3D.",$locations[0],"\%26pp\%3DSPECIFY_PP\%26fn\%3DSPECIFY_TOKEN\%26an\%3D1\%26prv\%3D1";
	} else {
		print "NONE";
	}
	print "\n";
	print "BACK_CH_PUB=NONE\n";

	print "BACK_CH_LOG=";
	if ($ReasonCode == TS_ID_REGULAR) {
		#logs are not uploaded, but without a valid url, log rotation does not happen in 3.0
		##"@http://204.176.49.6:80/tivo-service/acceptfile.cgi?type=.log&pp=SPECIFY_PP&fn=00200002024E92E&prv=0&an=0"
		print "$UPLOADBase"."tivo-service/acceptfile.cgi";
		if ($upload) {
			print "\%3Ftype\%3D.log\%26pp\%3DSPECIFY_PP\%26fn\%3D",$TCD_ID,"\%26prv\%3D0\%26an\%3D0";
		}
# @http://204.176.49.6:80/tivo-service/acceptfile.cgi?type=.30093&pp=SPECIFY_PP&fn=SPECIFY_TOKEN&an=1&prv=1
	} else {
		print "NONE";
	}
	print "\n";

	print "TIME_SVC=";
	if ($ReasonCode == TS_ID_REGULAR || $ReasonCode == TS_ID_SETUP) {
		print "/bin/ntpdate -b $ntp";
	} else {
		print "NONE";
	}
	print "\n";

	print "SEQ_COOKIE=12345678\n";
	print "INV_FILE=\n";
	print "NO_PRV_BACKHAUL=";
	if ($upload || $upgrade) {
		print BACKHAUL_NOCHANGE;
	} else {
		print $cfg->val("backhaul",$TCD_ID,BACKHAUL_NOPRIVATE);
	}
	print "\n";
	print "SERVICE_STATE=",$cfg->val("tcd_id",$TCD_ID,SERVICESTATE_GOOD),"\n";
	print "STATE_EXPIRE=",$cfg->val("expire",$TCD_ID,"0"),"\n";
	print "SW_SYSTEM_NAME=";
	if ($ReasonCode == TS_ID_SETUP) {
		print "none";
	} else {
		if ($upgrade) {
			my($v,$img,$end);
			my($current) = $cfg->val($swmodel,"current","3.0");
			$v = $cfg->val($current,"version","3.0-01-1-");
			($img) = $SW_LIST =~ /swsystem-(\d+)/;
			$end = $cfg->val("versions",$img,"000");
			$current = $v.$end;
			print "$current";
		} else {
			print "$tivoOSVersion";
		}
	}
	print "\n";
	print "INFO_CODE=\n";
	print "TCD_MESSAGE=\n";
	print "GLOBAL_MESSAGES=\n";
	print "KEY_SERVER=";
	if ($keyserver && !$upgrade) {
		my($keybase) = $cfg->val("keyserver","keyurlbase",$urlbase);
		my($keytivo) = $cfg->val("keyserver","usetivo",0);
		my($keyname) = "keyserver.cgi";
		$keyname = "keydist.cgi" if ($s11 == 0 && $keytivo != 0);
		print $keybase;
		if ($keytivo) {
			print $keyname;
		} else {
			print "tivo-service/$keyname";
		}
#		print "KEY_SERVER=http://204.176.49.4:80/keyserver.cgi\n";
	}
	print "\n";
	print "BACK_CH_THUMB=";
	if ($upload && $ReasonCode == TS_ID_REGULAR) {
		print "$UPLOADBase"."tivo-service/acceptfile.cgi\%3Ftype\%3D.",$locations[0],".th\%26pp\%3DSPECIFY_PP\%26fn\%3DSPECIFY_TOKEN\%26an\%3D1\%26prv\%3D1";
	} else {
		print "NONE";
	}
	print "\n";
	print "FORCE_BACKHAUL=0\n";
	print "PUBLIC_LOG_FILTER=";
	#PUBLIC_LOG_FILTER=[Ee]xception([^/]| [^P]| P[^O]| PO[^S]| POS[^T])|[Aa]ssert|[B]acktrace|[Ss]egmentation|[K]ernel panic|[D]riveStatusError|[e]rrDbNoMemory
	if ($upload || $upgrade) {
		print "[Ee]xception([^/]| [^P]| P[^O]| PO[^S]| POS[^T])|[Aa]ssert|[B]acktrace|[Ss]egmentation|[K]ernel panic|[D]riveStatusError|[e]rrDbNoMemory";
	}
	print "\n";
	if ($version < 3.0) {
		print "DBLOAD_ORDER=";
	} else {
		print "DB_LOAD_ORDER=";
	}
	print "PG.*\n";
	print "REGEN_TOKEN=0\n";
	print "BACKHAUL_DATA_ON=";
	if (!$upgrade) {
		print "$upload";
	}
	print "\n";
	print "PERSONAL_DATA_ON=";
	if (!$upgrade) {
		print "0";
	}
	print "\n";
	print "DATA_GROUP_LIST=";
	#DATA_GROUP_LIST=BS_standard_002,BS_standard,CB_Standard,CP_Standard,CR_Standard,CR_sa1_big,CR_sa1_monthly,CR_standard,CR_SnowyZoe,MI_Standard,MI_sa1_big,MI_sa1_monthly,MI_standard,SC_acura,SC_fox,SC_hbo,SC_logitech,SC_pbs,SC_porsche,SC_uni,SC_acura,SC_logitech,SC_pbs,SC_porsche,SC_tivoa,SC_discovy,SC_encore,SC_fixa,SC_fixb,SC_flix,SC_igdtv,SC_max,SC_mc,SC_nbc,SC_st,SC_starz,SC_sun,SC_tlnc,SC_west,SF_SerialLogging,SF_IntersilDownload,SH_sa1_big,SH_sa1_monthly,SH_standard,SI_TvSec,SW_released
	if ($upload) {
		my($x,$y,$dl,@list,$out,$xl);
		for $x ("BS","CB","CP","CR","MI","SC","SF","SH","SI","SW") {
			undef($dl);
			undef($xl);
			$dl = $cfg->val("showcases","download") if ($x eq "SC");
			$dl = $cfg->val("menuitems","download") if ($x eq "MI");
			$dl = $cfg->val($x,"download") if (!defined($dl));
			next if (!defined($dl));
			$xl = $cfg->val("showcases","sc$swmodel") if ($x eq "SC");
			$xl = $cfg->val("menuitems","mi$swmodel") if ($x eq "MI");
			$xl = $cfg->val($x,"$x$swmodel") if (!defined($xl));
			$dl .= ",".$xl if (defined($xl));
			(@list) = split(/,/,$dl);
			for $y (@list) {
				$out .= $x."_".$y.",";
			}
		}
		$x = length($out);
		$y = substr($out,0,$x-1);
		print $y;
#	print "BS_standard_002,BS_standard,CB_Standard,CP_Standard,CR_Standard,CR_sa1_big,CR_sa1_monthly,CR_standard,CR_SnowyZoe,MI_Standard,MI_sa1_big,MI_sa1_monthly,MI_standard,SC_acura,SC_fox,SC_hbo,SC_logitech,SC_pbs,SC_porsche,SC_uni,SC_acura,SC_logitech,SC_pbs,SC_porsche,SC_tivoa,SC_discovy,SC_encore,SC_fixa,SC_fixb,SC_flix,SC_igdtv,SC_max,SC_mc,SC_nbc,SC_st,SC_starz,SC_sun,SC_tlnc,SC_west,SF_SerialLogging,SF_IntersilDownload,SH_sa1_big,SH_sa1_monthly,SH_standard,SI_TvSec,SW_released";
	}
	print "\n";

	print "CAPRQST_URL=";
	print $urlbase."tivo-service/caprqst.cgi" if ($mercury);
	print "\n";
	print "TIMEOUT=\n";
	print "SUCCESS_TIME=\n";
	print "FAIL_TIME_LIST=\n";
	print "MERC_URL=";
	print $urlbase."tivo-service/mercury.cgi" if ($mercury);
	print "\n";
	print "MERC_UDP=";
	print "204.176.49.32:7884" if ($mercury);
	print "\n";
	print "MERC_ENABLED=";
	print "1" if ($mercury);
	print "\n";
	print "TCP_TIME_SVC=204.176.49.2\n";
	print "DATA_GROUP_INT_LIST=\n";
	if ($s1 == 0 || $s11 == 0) {
		print "NAG_NOTICE=\n";
		print "NAG_WARN=\n";
		print "NAG_CRITICAL=\n";
	}
	close(STDERR) if (defined($debuglog));
}
