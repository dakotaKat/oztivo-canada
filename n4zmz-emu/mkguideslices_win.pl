#!c:/Perl/bin/Perl.exe
#
# ---------------------------------------------------------------
#
# This script automates the process of creating a guide data
# slice file and delivering it to the service emulator.
# This is based on the mkguideslices script developed by N4zmz.
# 
# Copy this script into the C:\Tivo\guidedir directory
# 
# Since this script runs in the C:\Tivo\guidedir directory in
# order to run the parsexmlguide_vb application you need to
# create a windows batch file with the following statements:
#
# 	cd C:\Tivo\xmltv\parsexmlguide
# 	parsexmlguide -autostart -batch 
# 
# Save this file as "parsexmlguide.bat" in the C:\Tivo\xmltv
# directory. This is required because I couldn't get this 
# Perl script to execute parsexmlguide from the C:\Tivo\xmltv
# directory.
#
# ---------------------------------------------------------------


my($version) = "0.1";

use strict;
use Config::IniFiles;
use Date::Calc qw(Date_to_Days Add_Delta_Days Today Date_to_Text);
use File::stat;


sub date_calc (;$) {
	my($days) = @_;
	my($year,$month,$day,$epoch,$today,$diff);
	($year,$month,$day) = Today();
	$epoch = Date_to_Days(1970,01,01);
	if (defined($days)) {
		($year,$month,$day) = Add_Delta_Days($year,$month,$day,$days);
	}
	$today = Date_to_Days($year,$month,$day);
	$diff = $today-$epoch;
	return $diff;
}


MAIN: {

#
# Grab the parameters from the tivo.conf file
#
	my($cfg) = new Config::IniFiles(-file=>'tivo.conf',-nocase=>1);
	my($days) = $cfg->val("slices","days",7);
	my($dir) = $cfg->val("slices","directory");
	my($grabber) = $cfg->val("slices","country","na");
	my($head) = $cfg->val("slices","headend");
	my($offset) = $cfg->val("slices","offset");
	my($verbose) = $cfg->val("config","verbose",1);
	my($opt,@files,$i);

	my($deletedir) = "C:\\Tivo\\ToDelete";

	# If an offset is defined then add it as an option
	if (defined($offset)) {
		$opt = "--offset $offset ";
	}


	# Get todays date in the YYYYMMDD format 
	my ($year,$month,$day)=Today();
	my ($cdat) = sprintf ("%04d%02d%02d\n", $year, $month, $day);
	chomp $cdat;


	print  ("\n");
	print "-------------------------------------------------------\n";
	print "Using the following parameters from the tivo.conf file:\n\n";
	print "-------------------------------------------------------\n";
	print "Number of Days to caputure:      $days\n";
	print "xmltv Directory:                 $dir\n";
	print " xmltv country:                   $grabber\n";
	print " xmltv verbose (1=on,0=off):      $verbose\n";
	print " xmltv days offset:               $offset\n";
	print " xmltv options:                   $opt\n\n";
	print "Name of Headend:                 $head\n";
	print "Today's Date:                    $cdat\n";



# ---------------------------------------------------------------
# Cleaning Up
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("-------------------\n");
	print  ("--- CLEANING UP ---\n");
	print  ("-------------------\n");

	print  ("del /q $deletedir\n\n");
	system ("del /q $deletedir");


	print  ("rd /q /s .\\shows\n\n");
	system ("rd /q /s .\\shows");
	system ("md .\\shows");



# ---------------------------------------------------------------
# Run xmltv tv_grab_na to generate the XML listings file
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("------------------------------------------------------\n");
	print  ("--- RUNNING XMLTV TO GENERATE THE XML LISTING FILE ---\n");
	print  ("------------------------------------------------------\n");
	print  ("$dir\\xmltv tv_grab_$grabber $opt --config-file $dir\\.xmltv\\tv_grab_na.conf --days $days --output $dir\\$cdat.xml\n\n");

	$opt .= "--quiet " if (!$verbose);
	system ("$dir\\xmltv tv_grab_$grabber $opt --config-file $dir\\.xmltv\\tv_grab_na.conf --days $days --output $dir\\$cdat.xml");

	# Check that the xml file is not a zero byte file
	my($size) = stat("$dir\\$cdat.xml") -> size;
	if ($size == 0) {
		print  ("\n\n");
		print STDERR "WARNING! tv_grab_$grabber failure. No output file.\n";
		exit(1);
	}



# ---------------------------------------------------------------
# Run parsexmlguide_vb to generate the shows directory
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("----------------------------------------------------------------\n");
	print  ("--- RUNNING PARSEXMLGUIDE_VB TO GENERATE THE SHOWS DIRECTORY ---\n");
	print  ("----------------------------------------------------------------\n");
	print  ("$dir\\parsexmlguide\\parsexmlguide -autostart -batch -nogui\n\n");

	system ("$dir\\parsexmlguide.bat");



# ---------------------------------------------------------------
# Run mlsliice to generate the slice file
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("--------------------------------------------------\n");
	print  ("--- RUNNING MKSLICE TO GENERATE THE SLICE FILE ---\n");
	print  ("--------------------------------------------------\n");

	# Calculate the start date and end date of the guide data
	my($tdat) = date_calc();
	my($edat) = date_calc($days);
	if (defined($offset)) {
		$tdat = date_calc($offset);
		$edat = date_calc($offset + $days);
	}

	# Subtract 1 from the number of days
	$days--;

	# Run mkslice based on the start date and number of days of the sliice
	if ($days > 0) {
		print ("perl mkslice $tdat+$days > ./slices/$cdat.slice\n");
		system("perl mkslice $tdat+$days > ./slices/$cdat.slice");
	} else {
		print ("perl mkslice $tdat > ./slices/$cdat.slice\n");
		system("perl mkslice $tdat > ./slices/$cdat.slice");
	}


	# Check that the slice file is not a zero byte file
	$size = stat(".\\slices\\$cdat.slice") -> size;
	if ($size == 0) {
		print  ("\n\n");
		print STDERR "WARNING! Slice failure. No output file.\n";
		exit(1);
	}


	# Copy the slice file to the service emulator directory and rename it
	print  ("\n\ncopy .\\slices\\$cdat.slice C:\\Program Files\\Apache Group\\Apache2\\htdocs\\static\\listings\\$head"."_$tdat-$edat.slice\n\n");
	system ("copy .\\slices\\$cdat.slice \"C:\\Program Files\\Apache Group\\Apache2\\htdocs\\static\\listings\\$head"."_$tdat-$edat.slice\"");

	$size = stat("C:\\Program Files\\Apache Group\\Apache2\\htdocs\\static\\listings\\$head"."_$tdat-$edat.slice")->size;
	if ($size == 0) {
		print  ("\n\n");
		print STDERR "WARNING! Failed to copy slice file to service emulator. No output file\n";
		exit(1);
	}



# ---------------------------------------------------------------
# Cleaning Up
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("-------------------\n");
	print  ("--- CLEANING UP ---\n");
	print  ("-------------------\n");

	print  ("md $deletedir\n\n");
	system ("md $deletedir");

	print  ("\nmove $dir\\$cdat.xml $deletedir\n\n");
	system ("move $dir\\$cdat.xml $deletedir");

	print  ("\nmove .\\slices\\$cdat.slice $deletedir\n\n");
	system ("move .\\slices\\$cdat.slice $deletedir");



# ---------------------------------------------------------------
# All done
# ---------------------------------------------------------------
	print  ("\n\n");
	print  ("----------------\n");
	print  ("--- ALL DONE ---\n");
	print  ("----------------\n");

	for $i (@files) {
		unlink($i);
	}

}
