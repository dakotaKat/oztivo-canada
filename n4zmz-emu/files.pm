package files;

use Digest::SHA1;
use File::stat;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw (

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(find_files add_chksum $cfg $slicetype $usechksum $suffix
	$chksumsep $chksumsep2 %CACHE %FILES initialize_filecache
);

our $VERSION = (qw$Revision: 1.6 $)[1];
our $cfg;
our $slicetype;
our $usechksum;
our $suffix;
our $chksumsep;
our $chksumsep2;

our %FILES;
our %CACHE;

# Routine to cache the directory so that it should be faster to process
# during each search.
#

sub initialize_filecache($) {
	my($dir) = @_;
	my($file,$count,$modtime);
	$count = 0;
	my($now) = time();
	my($keepdays) = $cfg->val("config","keepmsgdays",365);
	my($deletefilesbefore) = int($now/86400) - $keepdays;
	opendir(DNAME, $dir);
	while($file = readdir(DNAME)) { 
		next if ($file eq "." || $file eq "..");
		next if (-d "$dir/$file");
		next if (! -r "$dir/$file");
		if ($file =~ /^message/) {
			$modtime = stat("$dir/$file")->mtime;
			if ($modtime <= $now - ($keepdays * 86400)) {
				unlink("$dir/$file");
				next;
			}
		}
		push @{$FILES{$dir}},$file;
		$count++;
	}
	closedir(DNAME);
	$CACHE{$dir} = 1;
	print STDERR "$count files cached for directory($dir)\n";
}


# Find a list of files in $dir (corresponding to $url)
# which the $fn prefix which are more recent than
# $version and (optionally) the $last timestamp.
#

sub find_files ($$$$;$$) {
	my($dir,$url,$fn,$version,$last,$allfiles) = @_;
	my($file,$chkversion,$short,$lineup);
	my($SW_LIST) = "";
	my($type);

	# Convert the supported 2-letter prefixes to allow for
	# user defined suffixes.  i.e. LG-merged instead of LG-standard
	if ($fn =~ /^(LG|GN|IR|AF|CR)$/) {
		$type = $cfg->val("slicetype",$fn,$slicetype);
	}
	# Loop over all of the entries in the $dir, ignoring
	# directories and non-readable files.
	print STDERR "In find_files $fn,$version,$dir and ",defined($last) ? $last : "","\n";
	if (!exists($CACHE{$dir}) || $CACHE{$dir} != 1) {
		initialize_filecache($dir);
	}
	foreach $file (@{$FILES{$dir}}) {
		# Deal with the potential slice files.
		if ($file =~ /\.slice(.gz)?$/i || $file =~ /\.slice\.bnd$/i ||
			$file =~ /\.snow(.bnd)/) {
			# Get the filename without the .slice... suffix
			$short = $file;
			$short =~ s/\.slice(.gz)?$//i;
			$short =~ s/\.slice\.bnd$//i;
			$short =~ s/\.snow(.bnd)$//i;
			# Get the name without the verion into $lineup
			$lineup = $short;
			$lineup =~ s/\_.*//;
			# Deal with headend files: LG,GN,IR,AF,CR
			if ($file =~ /^$fn[\_\-]/) {
				# Skip if the slicetype is wrong.
				next if (defined($type) && ($file !~ /$type/i));
				# Determine the version number on the file
				($chkversion) = $short =~ /-[vV]*(\d+)$/;
				if (defined($chkversion) && ($version ne "" && $version < $chkversion) || $version eq "") {
					# fix the bad entry for DBS headends
					# if the headend is not configured
					# correctly.  The tivo will send
					# version 0.
					if ($fn =~ /DBS\~/ && $version == 0) {
						my($modtime) = stat("$dir/$file")->mtime;
						next if ($modtime < $last);
					}
	print STDERR "Adding $file: $chkversion vs $version, type ",defined($type)? $type : "","\n";
					if (!defined($allfiles)) {
						# Only keep the highest version
						$SW_LIST = add_chksum($dir,$url,$file);
						$version = $chkversion;
					} else {
						# We want all files of this type
						$SW_LIST .= add_chksum($dir,$url,$file);
					}
				}
			}
		}
	}
	return $SW_LIST;
}

# Given a $file in a $dir, which also appears at $url,
# return a string with the full URL and a checksum.
# If noload is specified, add the extra parameters to
# keep the tivo from dbloading the file.
sub add_chksum ($$$;$) {
	my($dir,$url,$file,$noload) = @_;
	my($add) = "";
	my($chksum) = "";
	$url .= "/" if ($url !~ /\/$/);
	if (defined($noload)) {
		$add = "\&noload";
	}
	if ($usechksum) {
		$chksum = gen_chksum($dir,$file);
	}
	if ($chksum ne "") {
		return "$url$file"."$chksumsep"."chksum"."$chksumsep2"."0x$chksum$add|";
	} else {
		return "$url$file$suffix|";
	}
}

# Generate a SHA1 checksum.
sub gen_sha1chksum($) {
	my($fn) = @_;
	my($ctx) = new Digest::SHA1;
	open(FILE,"<$fn");
	binmode(FILE);
	$ctx->addfile(*FILE);
	close(FILE);
	return $ctx->hexdigest;
}

# Generate a SHA1 checksum as a hexadecimal string.
sub gen_chksum ($$) {
	my($dir,$file) = @_;
	my($ret) = "";
	my($hash1) = uc gen_sha1chksum("$dir/$file");
	my($i,@array_0123,@array_3210);
	for $i (0..19) {
		$array_0123[$i] = hex(substr($hash1,2*$i,2));
	}
	for $i (0..19) {
		$array_3210[$i] = $array_0123[3-($i%4)+(($i>>2)<<2)];
	}
	for $i (0..19) {
		$ret .= sprintf("%02X",$array_3210[$i]&0xff);
	}
	return $ret;
}

1;
