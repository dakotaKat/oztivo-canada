# Copyright 2003 Dennis Boylan, dennis@b-lan.com
# All rights reserverd.
# $Id: install.PL,v 1.15 2004/12/11 23:15:53 n4zmz Exp $
#

use Getopt::Long;

$VERSION = (qw$Revision: 1.15 $)[1];

@httpd_conf_search_path =
	("/etc/httpd/conf", "/usr/local/etc/apache", "/usr/local/etc/httpd",
	"/usr/local/etc/httpd/conf", "/usr/local/apache/conf",
	"/usr/local/httpd/conf", "/etc/httpd/","/etc/apache");
$download = $type = $can_logo = $emu_home = $emu_ip = $cvs_user = $cvs_pass = "";
%opt = ("help" => \&Usage, "home=s" => \$emu_home, "ip=s" => \$emu_ip,
	"canadian" => \$can_logo, "cvsuser=s" => \$cvs_user,
	"cvspass=s" => \$cvs_pass, "guidetype=s" => \$type,
	"nodownload" => \$download);

$result = Getopt::Long::GetOptions(\%opt,"help", "home=s", "ip=s","canadian+",
	"cvsuser=s","cvspass=s","guidetype=s","nodownload+");
if (${$opt{canadian}}) {
	$logo = "LG-merged-v69.slice.gz";
} else {
	$logo = "LG-standard-v110.slice.gz";
}
if (defined($opt{home})) {
	$emu_home = $opt{home};
} else {
	$emu_home = $ENV{PWD};
}
if (defined($opt{ip})) {
	$emu_ip = $opt{ip};
}
if (defined($opt{guidetype})) {
	$type = $opt{guidetype};
} else {
	$type = "xmltv";
}
for $i ("$emu_home","$emu_home/static","$emu_home/static/listings",
	"$emu_home/static/Headend","$emu_home/tivo-service",
	"$emu_home/guidedir","$emu_home/upload") {
	system("mkdir $i") if (! -d "$i");
}
system(qq!sed -e 's;/var/www/html;$emu_home;' -e 's;10.1.1.3;$emu_ip;' -e 's;/home/dennis/new/tivo/new-guide/xmltv2tivo;$emu_home/guidedir;' -e 's;guidetype=xmltv;guidetype=$type;' <tivo.conf >$emu_home/tivo-service/tivo.conf!);
for $i ("acceptfile.cgi","mlog.cgi","HServer.cgi","keyserver.cgi","mercury.cgi",
	"TCD411.cgi","config.pm","numtivos.pl","files.pm","debug.pm",
	"caprqst.cgi") {
	system("cp -p $i $emu_home/tivo-service;chmod 755 $emu_home/tivo-service/$i");
}
system("cd $emu_home/tivo-service;ln -s keyserver.cgi keydist.cgi");
system("touch $emu_home/tivo.log;chmod 666 $emu_home/tivo.log");
if ($download <= 0) {
for $i ("RM-cleanThumb.runme","RM-cleanThumb.runme.sig",
	"RM-addSeriesThumbs.runme","RM-addSeriesThumbs.runme.sig",
	"RM-ClearHeadendVersion.runme","RM-ClearHeadendVersion.runme.sig",
	"RM-varclean.runme","RM-varclean.runme.sig",
	"AF-standard-v42.slice.gz",
	"IR-standard-v175.slice.gz","$logo",
	"RM-RemoveObsoleteGenres.runme","RM-RemoveObsoleteGenres.runme.sig",
	"GN-standard-v54.slice.gz") {
	system(qq!cd $emu_home/static/Headend;wget http://www.b-lan.com/slices/$i!) if (! -e "$emu_home/static/Headend/$i");
}
}
add_httpd();
exit(0);

sub find_file ($$) {
  my($filename,@list) = @_;
  my(@result,$directory);
  foreach $directory (@list) {
    if (-e "$directory/$filename") {
       push @result,$directory;
    }
  }
  return @result;
}

sub add_httpd {

  ($http_dir) = &find_file("httpd.conf",@httpd_conf_search_path);
  $file = `cat $http_dir/httpd.conf`;
  if ($file =~ /Alias\s+\/tivo-service/) {
	  if ($file =~ /\#\# emukey: cgi v1.0/) {
		  print "Skipping httpd configuration\n";
	  	  return;
	  }
	  print "Alias exists, but not created by us.\n";
	  return;
  }
  
  open(HTTPD,">>$http_dir/httpd.conf") || die "cannot open $http_dir/httpd.conf for appending: $!";
  print HTTPD <<EOF;
############################
## Added by EMU
## emukey: cgi v1.0
############################
Alias /tivo-service "$emu_home/tivo-service"
Alias /static "$emu_home/static"
<Directory "$emu_home/tivo-service">
  AllowOverride None
  Options ExecCGI
  Order allow,deny
  Allow from all
</Directory>
############################
## emukeyend: cgi v1.0
############################
EOF
  close(HTTPD);
}

sub Usage {
  print STDERR <<"USAGE";
Usage: perl $0 [options]

Possible options are:

  --help		Display this screen.

  --home=<dir>		Use the directory <home> for files.

  --ip=<ipaddr>		Use the IP address <ipaddr> for the webserver

  --cvsuser=<user>	Use the username <user> for cvs access

  --cvspass=<pass>	Use the password <pass> for cvs access

  --canadian		Download the canadian logos instead of the normal logos

  --nodownload		Do not download any of the standard files

  --guidetype=<opt>	Use <opt> for the type of guide (xmltv or parse)

USAGE
	exit(1);
}

