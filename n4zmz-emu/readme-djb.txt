# $Id: readme-djb.txt,v 1.22 2005/01/15 20:15:05 n4zmz Exp $

This is a highly modified version of Dan and Nick's emulator package
which uses a configuration file and supports debugging.

Also included is mkguideslices.pl and readme.mkguideslices

New support for message slices.  It does require that if you want to use
the tivo message slices that you rename them to be .slice instead of .slic.

Requires Config::IniFiles version 2.37 or higher
Requires Digest::SHA1 to replace external sha program.
Requires File::Flock to lock the status log.
Requires URI::Escape to properly handle 7.x software
Requires Compress::Zlib to properly handle 7.x software

Minimal version 7.x support added.

New 1.3 support and upgrade support.

New cgis are included.  Also, if you have a series 2 tivo, you should
make sure that keydist.cgi is either a copy of the keyserver.cgi or
a link to it.

New installer is available.

usage:
	perl install.PL --help

Config file name is 'tivo.conf'

Section [config]
	urlbase		base for url http://a.b.c.d:port/
	urlslicedir	what gets appended to urlbase
	slicedir	physical directory for guide slices
	urlheaddir	what gets appended to urlbase
	headenddir	physical directory for non-guide slices (def=slicedir)
	logfile		file name for status messages (obsolete)
	statuslog	file name for status messages
	debug		debugging status (0=off, 1=on)
	downloadall	force downloading of all guide slices (0=off, 1=on)
	ntpserver	NTP Server addresses
	verbose		Verbose enabled (0=off, 1=on)
	keepdays	Number of days after end day of slice to keep
	maxslicedays	Number of days from modification of slice to keep
	useupload	Turn on Upload file support (0=off, 1=on)
	usemercury	Turn on mercury support (0=off, 1=on)
	usekeyserver	Turn on keyserver support (0=off, 1=on)
	usetollfree	Turn on Tollfree support (0=off, 1=on)
	tollfree	Toll Free Number
	slicetype	String value for download (default is standard)

Section [ignore]
	irdbversion	1 = Use tivo version , 0 = Use timestamp
	genreversion
	logoversion
	affiliationverion

Section [slicetype]
	ir		Defaults to slicetype
	gn
	af
	lg
	cr

Section [upload]
	directory	Directory location of where to put the uploaded files.

Section [tcd_id]
	<serialno>	what the service state to send to tivo defaults to 3

Section [expire]
	<serialno>	The expiration tivo date defaults to 0 (none)

Section [slices]
	See readme.mkguideslices

Section [debug]
	logfile		Which file should get debugging output.  Defaults to
			standard error (webserver error_log)

Section [<serialno>]
	servicestate	Same as section tcd_id
	expire		Same as section expire
	<overridden parameter> Any parameter used elsewhere in the config file
			but specific to this tivo.

Configuration

The two parameters urlbase and urlslicedir are concatenated to produce a full
URL which should correspond to the slicedir.

example:
document root=/var/www/html
urlbase=http://10.1.1.1:80/
urlslicedir=static/listings/
slicedir=/var/www/html/static/listings/

the full URL would look like http://10.1.1.1:80/static/listings/

If you have indexing enabled on the directory, you should be able to see your
slices from a browser.  If indexing is not enabled, you can append a slice
file name and try to download it.

Guided Setup

TCD411 now supports returning the correct phone slice.  The phone slices are of the format:
	AC-<areacode>-v<version>.slice[.gz]

It will only will load new phone slices if the version number is greater than
the current loaded version number.

HServer now supports loading the headend slice by zipcode. Headend slices are
of the format for cable/Antenna:
	<zipcode>-<version>.slice[.gz]

HServer now supports loading the logo slice.  Logo slices are of the format:
	LG-<description>-v<version>.slice[.gz]

HServer now supports loading the IR slice.  IR slices are of the format:
	IR-<description>-v<version>.slice[.gz]

HServer now supports loading the AF (affiliation) slice.  AF slices are of the
format:
	AF-<description>-v<version>.slice[.gz]

