#!/usr/bin/perl
#
# Zap2it(tm) DataDirect(tm) Client
# Author: JRB 
#
#  $Id: datadirect-parser.pl,v 1.31 2004/10/26 01:05:53 dboardman Exp $
#

package ddparserSAXHandler;

use strict;
use warnings;
use utf8;

use XML::Parser;

sub new { return bless {}; }

my $handler = {
                 Start => \&ddparserSAXHandler::start_element,
                 End   => \&ddparserSAXHandler::end_element,
                 Char  => \&ddparserSAXHandler::characters,
                };

use FindBin qw($Bin);

use Config::IniFiles 2.37;
use Data::Dumper;
use DBI;
use GDBM_File;
use Getopt::Long;
use Time::Piece;
use Text::Iconv;

# Switch to this program's directory
chdir($Bin);

use constant DESTINATION_MESSAGE_BOARD => 1;
use constant DESTINATION_PRE_TIVO_CENTRAL => 2;
use constant PRIORITY_HIGH => 1;
use constant PRIORITY_LOW => 3;
use constant PRIORITY_MEDIUM => 2;

my @StartTime = localtime( time() );
my $ValidTime = sprintf( "%4d%02d%02d%02d%02d%02d",
			 $StartTime[5] +1900,
			 $StartTime[4] +1,
			 $StartTime[3],
			 $StartTime[2],
			 $StartTime[1],
			 $StartTime[0] );
print STDERR "Valid time [$ValidTime]\n";
# Mysql times are localtime based.

my $Start;

#//////////////////////DEFAULT CONFIGURATION VARIABLES//////////////////////////////////////

binmode(STDOUT, ":utf8");
sub Convert( $ )
{
    my $value = shift();
    if (defined($value)) {
        utf8::decode($value);
    }
    return $value;
}

my $CurrentDay = time() / 86400;
$CurrentDay =~ s/\..*$//;

my($cfg_stations);
my $cfgFilename = "config.ini";
my $cfg = new Config::IniFiles(-file=>$cfgFilename,-nocase=>1);
my($cfgStationsfn) = "config-channels.ini";
if (-r $cfgStationsfn) {
	$cfg_stations = new Config::IniFiles(-file=>$cfgStationsfn,-nocase=>1);
	if (!defined($cfg_stations)) {
		my($i);
		for $i (0..$#Config::IniFiles::errors) {
			print STDERR $Config::IniFiles::errors[$i],"\n";
		}
		exit(1);
	}
}

sub cfg_val ($$;$) {
	my($section,$index,$def) = @_;
	my($ret) = $def;
	if (defined($cfg_stations)) {
		$ret = $cfg_stations->val($section,$index,$def);
	}
	$ret = $cfg->val($section,$index,$ret);
	return $ret;
}

our $filename = "datadirect.xml";
our $Database = $cfg->val("database","name","tvdata");
our $dBUser = $cfg->val("database","user",'dbuser');
our $dBPassword = $cfg->val("database","password",'dbpassword');
my $dbtype = $cfg->val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my $MaxStation = 1100000;
my %Channels;
my $Line;
if (-e "stations.txt")
{
    open STATIONS, "stations.txt";
    while( $Line = <STATIONS> )
    {
        next if ($Line =~ /^\#/);
        my @Info = split(',',$Line);
        $Info[4] =~ s/\s*$//;
        $Channels{$Info[4]}->{TivoStation} = $Info[3];
        if( $MaxStation < $Info[3] )
        {
	    $MaxStation = $Info[3];
        }
    }
    close STATIONS;
}
if (-e "stations_auto.txt")
{
    open STATIONS, "stations_auto.txt";
    while( $Line = <STATIONS> )
    {
        next if ($Line =~ /^\#/);
        my @Info = split('\|',$Line);
        $Info[4] =~ s/\s*$//;
        $Channels{$Info[4]}->{TivoStation} = $Info[3];
        if( $MaxStation < $Info[3] )
        {
	    $MaxStation = $Info[3];
        }
    }
    close STATIONS;
}
use vars qw( %ProgTable );
my $myProgFile="./myprogid";

tie (%ProgTable, "GDBM_File", $myProgFile, &GDBM_WRCREAT, 0644);

my %GenericSQL;
$GenericSQL{TVRATINGS}->{SELECT} = $connection->prepare("SELECT * FROM TvRatings");
$GenericSQL{CASTROLES}->{SELECT} = $connection->prepare("SELECT * FROM CastRoles");
$GenericSQL{ADVISORY}->{SELECT} = $connection->prepare("SELECT * FROM Advisories WHERE advisory=?");
$GenericSQL{MPAA}->{SELECT} = $connection->prepare("SELECT * FROM MpaaRatings WHERE mpaarating=?");
$GenericSQL{STAR}->{SELECT} = $connection->prepare("SELECT * FROM StarRatings WHERE starrating=?");
$GenericSQL{SHOWTYPE}->{SELECT} = $connection->prepare("SELECT * FROM ShowTypes WHERE showtype=?");

$GenericSQL{STATION}->{SELECT} = $connection->prepare("SELECT * FROM Stations WHERE station_id=?");
$GenericSQL{STATION}->{UPDATE} = $connection->prepare("UPDATE Stations SET callsign=?, name=?, affiliate=?, station_tivo_id=?, station_ver = station_ver+1 WHERE station_id=?");
$GenericSQL{STATION}->{INSERT} = $connection->prepare("INSERT INTO Stations (callsign, name, affiliate, station_id, station_tivo_id, station_ver) VALUES (?,?,?,?,?,?)");

$GenericSQL{SERIES}->{SELECT1} = $connection->prepare("SELECT * FROM Series WHERE series_id=?");
$GenericSQL{SERIES}->{INSERT1} = $connection->prepare("INSERT INTO Series (series_id, series_tivoid, series_ver, series_title) VALUES (?,?,1,?)");
$GenericSQL{SERIES}->{UPDATE1} = $connection->prepare("UPDATE Series SET series_ver=series_ver+1, series_title=? WHERE series_id=?");
$GenericSQL{SERIES}->{SELECT2} = $connection->prepare("SELECT * FROM Series WHERE series_title=?");
$GenericSQL{SERIES}->{INSERT2} = $connection->prepare("INSERT INTO Series (series_id, series_tivoid, series_ver, series_title) VALUES ('',?,1,?)");
$GenericSQL{SERIES}->{UPDATE2} = $connection->prepare("UPDATE Series SET series_ver=series_ver+1, series_id=? WHERE series_title=?");

$GenericSQL{PROGRAM}->{SELECT} = $connection->prepare("SELECT * FROM Programs WHERE program_tmsid=? ORDER BY program_ver limit 1");
$GenericSQL{PROGRAM}->{INSERT1} = $connection->prepare("INSERT INTO Programs ( series_id, program_tmsid, program_ver, program_title, program_subtitle, program_description, syndicated_episode_number, original_air_date, showtype_id, program_tivoid ) VALUES (?,?,1,?,?,?,?,?,?,?)");
$GenericSQL{PROGRAM}->{UPDATE} = $connection->prepare("UPDATE Programs SET program_ver=program_ver+1, program_title=?, program_subtitle=?, program_description=?, syndicated_episode_number=?, original_air_date=?, showtype_id=?, program_tivoid=?, series_id=? WHERE program_tmsid=?");
$GenericSQL{PROGRAM}->{UPDATED} = $connection->prepare("UPDATE Programs SET program_ver=program_ver+1 WHERE program_tmsid=? AND updated<?");
$GenericSQL{PROGRAM}->{INSERT2} = $connection->prepare("INSERT INTO Programs ( series_id, program_tmsid, program_ver, program_title, program_subtitle, program_description, syndicated_episode_number, original_air_date, showtype_id, program_tivoid ) VALUES ('',?,1,?,?,?,?,?,?,?)");

$GenericSQL{PROGRAMS}->{UPDATESERIESTIVOID}  = $connection->prepare("UPDATE Programs,Series SET Programs.series_tivoid=Series.series_tivoid WHERE Series.series_id=Programs.series_id AND Programs.series_id<>''");
$GenericSQL{PROGRAMS}->{UPDATESERIESTIVOID2} = $connection->prepare("UPDATE Programs,Series SET Programs.series_tivoid=Series.series_tivoid WHERE Series.series_title=Programs.program_title AND Programs.series_id=''");

$GenericSQL{MOVIE}->{INSERT} = $connection->prepare("INSERT INTO MovieInfo (program_tmsid, program_ver, mpaarating_id, starrating_id, year, runtime) VALUES (?,1,?,?,?,?)");
$GenericSQL{MOVIE}->{UPDATE} = $connection->prepare("UPDATE MovieInfo SET program_ver=program_ver+1, mpaarating_id=?, starrating_id=?, year=?, runtime=? WHERE program_tmsid=?");


$GenericSQL{CREW}->{SELECT} = $connection->prepare("SELECT crew_id FROM Crew WHERE givenname=? AND surname=?");
$GenericSQL{CREW}->{INSERT} = $connection->prepare("INSERT INTO Crew(givenname,surname) VALUES (?,?)");

$GenericSQL{PROGRAMCAST}->{SELECT} = $connection->prepare("SELECT ProgramCast.* FROM Crew, ProgramCast WHERE Crew.crew_id = ProgramCast.crew_id AND givenname=? AND surname=? AND castrole_id=? AND program_tmsid=?");
$GenericSQL{PROGRAMCAST}->{INSERT} = $connection->prepare("INSERT INTO ProgramCast(crew_id,castrole_id,program_tmsid) VALUES (?,?,?)");


$GenericSQL{PROGRAMGENRE}->{SELECT} = $connection->prepare("Select Genres.genre_id, relevance from Genres left join ProgramGenre ON Genres.genre_id = ProgramGenre.genre_id AND program_tmsid = ? Where genre = ?");
$GenericSQL{PROGRAMGENRE}->{INSERT} = $connection->prepare("INSERT INTO ProgramGenre(program_tmsid,genre_id,relevance) VALUES (?,?,?)");
$GenericSQL{PROGRAMGENRE}->{UPDATE} = $connection->prepare("UPDATE ProgramGenre SET relevance=? WHERE program_tmsid=? AND genre_id=?");

$GenericSQL{PROGRAMADVISORY}->{SELECT} = $connection->prepare("SELECT * FROM ProgramAdvisories WHERE program_tmsid=? AND advisory_id=?");
$GenericSQL{PROGRAMADVISORY}->{INSERT} = $connection->prepare("INSERT INTO ProgramAdvisories(program_tmsid,advisory_id) VALUES (?,?)");

$GenericSQL{SCHEDULE}->{SELECT} = $connection->prepare( "SELECT * FROM Schedule WHERE schedule_day=? AND schedule_time=? AND station_id=? AND program_tmsid=? ORDER BY valid DESC LIMIT 1" );
$GenericSQL{SCHEDULE}->{INSERT} = $connection->prepare( "INSERT INTO Schedule(schedule_day, schedule_time, station_id, program_tmsid, schedule_duration, tvrating_id, closecaption, hdtv, letterbox, subtitled, stereo, repeat, part_id, part_max, valid) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" );
$GenericSQL{SCHEDULE}->{UPDATE} = $connection->prepare( "UPDATE Schedule SET program_tmsid=?, schedule_duration=?, tvrating_id=?, closecaption=?, hdtv=?, letterbox=?, subtitled=?, stereo=?, repeat=?, part_id=?, part_max=?, valid=? WHERE schedule_day=? AND schedule_time=? AND station_id=?");
$GenericSQL{SCHEDULE}->{UPDATEVALID} = $connection->prepare( "UPDATE Schedule SET valid=? WHERE schedule_day=? AND schedule_time=? AND station_id=? and program_tmsid=?");

$GenericSQL{LINEUP}->{SELECT} = $connection->prepare("SELECT * FROM Lineups WHERE (lineup_tmsid=? OR lineup_tmsid is NULL) AND lineup_name=? AND lineup_type=? AND lineup_device=? AND lineup_postalcode=?");
$GenericSQL{LINEUP}->{SELECTNULL} = $connection->prepare("SELECT * FROM Lineups WHERE (lineup_tmsid=? OR lineup_tmsid is NULL) AND lineup_name=? AND lineup_type=? AND lineup_device is NULL  AND lineup_postalcode=?");
$GenericSQL{LINEUP}->{INSERT} = $connection->prepare("INSERT INTO Lineups( lineup_ver, lineup_tmsid, lineup_name, lineup_type, lineup_device, lineup_postalcode, tivo_postalcode, postal_location, lineup_location) VALUES (1,?,?,?,?,?,?,?,?)");
$GenericSQL{LINEUP}->{UPDATE} = $connection->prepare("UPDATE Lineups SET lineup_ver=lineup_ver+1, lineup_tmsid=?, lineup_name=?, lineup_type=?, lineup_device=?, lineup_postalcode=?, lineup_location=? WHERE lineup_id=?");
$GenericSQL{LINEUPMAP}->{SELECT1} = $connection->prepare("SELECT * FROM Lineup_map WHERE lineup_id=? AND station_id=? AND channel_num=?");
$GenericSQL{LINEUPMAP}->{SELECT2} = $connection->prepare("SELECT * FROM Lineup_map WHERE lineup_id=?");
$GenericSQL{LINEUPMAP}->{DELETE} = $connection->prepare("DELETE FROM Lineup_map WHERE lineup_id=?");
$GenericSQL{LINEUPMAP}->{INSERT} = $connection->prepare("INSERT INTO Lineup_map(lineup_id, station_id, channel_num, from_date, to_date) VALUES (?,?,?,?,?)");
$GenericSQL{POSTALCODE}->{SELECT} = $connection->prepare("SELECT * FROM PostalCodes WHERE tivo_postalcode=? AND postal_location=?");
$GenericSQL{POSTALCODE}->{INSERT} = $connection->prepare("INSERT INTO PostalCodes(tivo_postalcode, postal_location) VALUES (?,?)");
$GenericSQL{POSTALCODE}->{UPDATE} = $connection->prepare("UPDATE PostalCodes SET postalcode_ver=postalcode_ver+1 WHERE tivo_postalcode=? AND postal_location=?");

$GenericSQL{MESSAGES}->{SELECT} = $connection->prepare("SELECT message FROM Messages WHERE message=? AND destination=?");
$GenericSQL{MESSAGES}->{INSERT} = $connection->prepare("INSERT INTO Messages(subject,sender,message,priority,expiration_day,destination,valid) VALUES (?,?,?,?,?,?,?)");
#///////////////////////////////////////////////////////////////////////////////////////////

my $Verbose = 0;

### Values on command line, if provided, overwrite defaults

GetOptions(     "filename=s"      =>      \$filename,
            'verbose:i'       => \$Verbose,
            'v:i'             => \$Verbose
          );

#preload tvratings
my %TvRatings;

if( $GenericSQL{TVRATINGS}->{SELECT}->execute() ) 
{
     while (my $row = $GenericSQL{TVRATINGS}->{SELECT}->fetchrow_hashref())
     {
           $TvRatings{$row->{tvrating}} = $row->{tvrating_id};
     }
}

#preload castroles
my %CastRoles;
if( $GenericSQL{CASTROLES}->{SELECT}->execute() ) 
{
     while (my $row = $GenericSQL{CASTROLES}->{SELECT}->fetchrow_hashref())
     {
           $CastRoles{$row->{castrole}} = $row->{castrole_id};
     }
}

my $parser = XML::Parser->new( Handlers => $handler);

Text::Iconv->raise_error(1);

my $doc = $parser->parsefile($filename);
my @TagStack = ();

my $Accumulator;

my %CurStation;

my %CurLineup;
my %CurStationMap;

my %CurProgram;
my %CurMember;
my %CurSched;
my $CurrentCrewUpdated;
my @Schedule;

my %PostalCodesNeedingUpdate;

sub start_element($$) {
    my( $self, $element, @attrsandvals ) = @_;

    my %attrs;
    # @Array returns a scalar in this context
    my $ending_value = scalar(@attrsandvals) ;
    for(my $counter=0 ; $counter < $ending_value ; $counter += 2)
    {
        $attrs{$attrsandvals[$counter]} = $attrsandvals[$counter+1];
    }

    unshift @TagStack, $element;
    $Accumulator='';
    if( $element eq 'station' )
    {
	%CurStation = (station_id => $attrs{id});
    } elsif ( $element eq 'lineup' ) {
	    my $dev;
	    if (defined($attrs{device}))
	    {
		    $dev = $attrs{device};
	    }
	    else
	    {
		    $dev = "Extended Basic";
	    }
	%CurLineup = ( tmsid  => $attrs{id},
		       name   => $attrs{name},
		       type   => $attrs{type},
		       device => $dev,
		       postal => $attrs{postalCode},
		       location => $attrs{location}
			   );
    } elsif ( $element eq 'map' ) {
	push @{$CurLineup{stations}}, { station_id => $attrs{station},
					channel_num => $attrs{channel},
                                        from    => $attrs{from},
                                        to      => $attrs{to} };
    } elsif ( $element eq 'program' ) {
	%CurProgram = (
			program_tmsid => $attrs{id});
    } elsif (( $element eq 'programGenre' ) ||
             ( $element eq 'crew' )){
	%CurProgram = (
			program_tmsid => $attrs{program});
    } elsif ( $element eq 'schedule' ) {
	my $myTime = Time::Piece->strptime($attrs{'time'}, '%Y-%m-%dT%H:%M:%SZ')->epoch();
        my $SchedDay = $myTime/86400;
        $SchedDay =~ s/\..*//;
        my $SchedTime = $myTime - ($SchedDay*86400);
	my $Duration = $attrs{duration};
	if( $Duration =~ /PT([0-9]+)H([0-9]+)M/ )
	{
	    my $Hours = $1;
	    my $Min = $2;
	    my $Mins = $Hours*60 + $Min;
	    $Duration = ($Hours*60 + $Min)*60;
	}
	%CurSched = (
		      program_tmsid => $attrs{program},
		      station_id => $attrs{station},
		      schedule_day=> $SchedDay,
		      schedule_time=> $SchedTime,
		      schedule_duration=> $Duration,
		      closecaption => (defined($attrs{closeCaptioned})&&($attrs{closeCaptioned}=~/t/i))||undef,
		      stereo  => (defined($attrs{stereo})&&($attrs{stereo}=~/t/i))||undef,
		      repeat  => (defined($attrs{repeat})&&($attrs{repeat}=~/t/i))||undef,
		      subtitled  => (defined($attrs{subtitled})&&($attrs{subtitled}=~/t/i))||undef,
		      hdtv  => (defined($attrs{hdtv})&&($attrs{hdtv}=~/t/i))||undef,
		      letterbox => undef,
		      tvRating => $attrs{tvRating}
		      );
    } elsif ( $element eq 'part' ) {
	$CurSched{part_max} = $attrs{total};
	$CurSched{part_id} = $attrs{number};
    } elsif ( $element eq 'stations' ) {
	$Start = time();
    } elsif ( $element eq 'lineups' ) {
	$Start = time();
    } elsif ( $element eq 'schedules' ) {
	$Start = time();
    } elsif ( $element eq 'programs' ) {
	$Start = time();
    } elsif ( $element eq 'productionCrew' ) {
	$Start = time();
    } elsif ( $element eq 'genres' ) {
	$Start = time();
    }
}
sub HandleSchedule( $ )
{
    my $Schedule = shift();

    my $row;
# find the tvrating
    if( defined( $Schedule->{tvRating} ) )
    {
        if( exists($TvRatings{ $Schedule->{tvRating} } ))
        {
  	    $Schedule->{tvrating_id} = $TvRatings{ $Schedule->{tvRating} };
        } else {
            print STDERR "TV Rating of $Schedule->{tvRating} not defined\n";
        }
        delete $Schedule->{tvRating};
    }

    my $InsertIt = 0;
    if( $GenericSQL{SCHEDULE}->{SELECT}->execute( $Schedule->{schedule_day},
						  $Schedule->{schedule_time},
                                                  $Schedule->{station_id},
                                                  $Schedule->{program_tmsid}) &&
         ($row = $GenericSQL{SCHEDULE}->{SELECT}->fetchrow_hashref() ) )
    {
	if( TestAllFields( $Schedule, $row ) )
	{
	    if( $GenericSQL{SCHEDULE}->{UPDATEVALID}->execute( $ValidTime, $Schedule->{schedule_day},
							$Schedule->{schedule_time}, $Schedule->{station_id},
							$Schedule->{program_tmsid}) &&
		($GenericSQL{SCHEDULE}->{UPDATEVALID}->rows() > 0)  )
	    {
	    } else {
		print STDERR "Couldn't update valid time on $ValidTime, $Schedule->{schedule_day}, $Schedule->{schedule_time}, $Schedule->{station_id}\n";
		$InsertIt = 1;
	    }
	} else {
	    #print "Schedule changed\n";
	    #print Dumper $Schedule;
	    #print Dumper $row;
	    if( $GenericSQL{SCHEDULE}->{UPDATE}->execute( $Schedule->{program_tmsid},
							  $Schedule->{schedule_duration},
							  $Schedule->{tvrating_id},
							  $Schedule->{closecaption},
							  $Schedule->{hdtv},
							  $Schedule->{letterbox},
							  $Schedule->{subtitled},
							  $Schedule->{stereo},
							  $Schedule->{repeat},
							  $Schedule->{part_id},
							  $Schedule->{part_max},
							  $ValidTime,
							  $Schedule->{schedule_day},
							  $Schedule->{schedule_time},
							  $Schedule->{station_id}
							  ) &&
		($GenericSQL{SCHEDULE}->{UPDATE}->rows() > 0) )
	    {
		print "Succeeded update $Schedule->{schedule_day}, $Schedule->{schedule_time},$Schedule->{station_id}, $Schedule->{program_tmsid} RowCount=".$GenericSQL{SCHEDULE}->{UPDATE}->rows()."\n";
	    } else {
		print STDERR "Failed update $Schedule->{schedule_day}, $Schedule->{schedule_time},$Schedule->{station_id}, $Schedule->{program_tmsid}\n";
		print STDERR "Inserting duplicate\n";
		$InsertIt=1;
	    }

	}
    } else {
	$InsertIt = 1;
    }
    if( $InsertIt )
    {
        #print Dumper $Schedule;
        #print "tvrating = $tvRating\n";
        if( $GenericSQL{SCHEDULE}->{INSERT}->execute( $Schedule->{schedule_day},
                                                      $Schedule->{schedule_time},
                                                      $Schedule->{station_id},
                                                      $Schedule->{program_tmsid},
                                                      $Schedule->{schedule_duration},
                                                      $Schedule->{tvrating_id},
                                                      $Schedule->{closecaption},
                                                      $Schedule->{hdtv},
                                                      $Schedule->{letterbox},
                                                      $Schedule->{subtitled},
                                                      $Schedule->{stereo},
                                                      $Schedule->{repeat},
                                                      $Schedule->{part_id},
                                                      $Schedule->{part_max},
						      $ValidTime ) )
        {
        } else {
            print STDERR "Failed to insert into Schedule\n";
        }
    }

                                                  

}

sub FindTvRating( $ )
{
    $GenericSQL{TVRATING}->{SELECT}->execute( shift() );
    my $row = $GenericSQL{TVRATING}->{SELECT}->fetchrow_hashref();
    $GenericSQL{TVRATING}->{SELECT}->finish();
    return $row->{tivorating};
}

sub HandleStation( $ )
{
    my $Station = shift();
    my $row;
    my($version) = cfg_val($Station->{callsign},"version",1);
    $Station->{station_ver} = $version if ( !exists($Station->{station_ver} ) );
    if( !exists( $Channels{$Station->{station_id}}->{TivoStation} ) )
    {
	$MaxStation++;
	my $NewNum = cfg_val($Station->{callsign},"serverid",$MaxStation);
	open AUTOSTATION, ">> stations_auto.txt";
	print AUTOSTATION "1|$Station->{callsign}|$Station->{name}|$NewNum|$Station->{station_id}\n";
	close AUTOSTATION;
	$Channels{$Station->{station_id}}->{TivoStation} = $NewNum;
    }
    if( $GenericSQL{STATION}->{SELECT}->execute( $Station->{station_id} ) &&
	($row = $GenericSQL{STATION}->{SELECT}->fetchrow_hashref()))
    {
	if( TestAllFields( $Station, $row ) )
	{
	}
	elsif( $GenericSQL{STATION}->{UPDATE}->execute( $Station->{callsign},
					       Convert($Station->{name}),
					       $Station->{affiliate},
					       $Channels{$Station->{station_id}}->{TivoStation},
					       $Station->{station_id}) )
	{
	    # Found a record, check to see if fields were updated
	    if( $GenericSQL{STATION}->{UPDATE}->rows() == 0 )
	    {
		# nothing updated.  Good.
		print STDERR "Station $Station->{station_id} not updated\n";
	    } else {
		print "Station $Station->{station_id} updated\n";
	    }
	}
    }
    elsif( $GenericSQL{STATION}->{INSERT}->execute( $Station->{callsign},
    				        Convert($Station->{name}),
    				        $Station->{affiliate},
				        $Station->{station_id},
					$Channels{$Station->{station_id}}->{TivoStation},
					$Station->{station_ver}) )
    {
        # Just added a record
	#print "Station $Station->{station_id} added\n";
    } else {
        # Couldn't add a record for some reason...
	print STDERR "Station $Station->{station_id} had problems\n";
    }
}
sub HandleSeries( $$$ )
{
    my ($Series_id, $SeriesTiVoId, $Series_title) = @_;
    my $Record;
    if( defined($Series_id) && ($Series_id ne "") )
    {
        if( $GenericSQL{SERIES}->{SELECT1}->execute( $Series_id ) &&
            ($Record = $GenericSQL{SERIES}->{SELECT1}->fetchrow_hashref()) )
        {
            if( TestAllFields( { series_id => $Series_id,
                                 series_title => $Series_title }, $Record ) )
            {
            } else {
                $GenericSQL{SERIES}->{UPDATE1}->execute( Convert($Series_title), $Series_id );
                print "Series updated $Series_title\n";
            }
        } elsif( $GenericSQL{SERIES}->{SELECT2}->execute( $Series_title ) &&
            ($Record = $GenericSQL{SERIES}->{SELECT2}->fetchrow_hashref()) )
        {
            if( TestAllFields( { series_id => $Series_id,
                                 series_title => $Series_title }, $Record ) )
            {
            } else {
                if ($Record->{series_id} eq "")
                {
                    $GenericSQL{SERIES}->{UPDATE2}->execute( $Series_id, Convert($Series_title) );
                    print "Series updated $Series_title\n";
                }
                else
                {
                    # The same title has 2 different series_id's
                    if ( $GenericSQL{SERIES}->{INSERT1}->execute( $Series_id, $SeriesTiVoId,
                           Convert($Series_title) ) ) {
                        print STDERR "Inserted duplicate for $Series_title [$Series_id]\n";
                    } else {
                        print STDERR "Failed insert $Series_title [$Series_id]\n";
                    }
                }
            }
        } elsif ( $GenericSQL{SERIES}->{INSERT1}->execute( $Series_id, $SeriesTiVoId,
                    Convert($Series_title) ) ) {
            #print "Successfully inserted $Series_title\n";
        } else {
            print STDERR "Failed insert $Series_title\n";
	}
    } else {
        if( $GenericSQL{SERIES}->{SELECT2}->execute( $Series_title ) &&
            ($Record = $GenericSQL{SERIES}->{SELECT2}->fetchrow_hashref()) )
        {
            if( TestAllFields( { series_id => $Series_id,
                                 series_title => $Series_title }, $Record ) )
            {
            } else {
                $GenericSQL{SERIES}->{UPDATE2}->execute( $Series_id, Convert($Series_title) );
                print "Series updated $Series_title\n";
            }
        } elsif ( $GenericSQL{SERIES}->{INSERT2}->execute( $SeriesTiVoId,
                    Convert($Series_title) ) ) {
            #print "Successfully inserted $Series_title\n";
        } else {
            print STDERR "Failed insert $Series_title\n";
        }
    }
}
sub HandleCrew( $$ )
{
    my $Member = shift();
    my $Program = shift();
    my $row;
    my $CrewId;
    my $CastRoleId;
    my $Updated = 0;

    # find the castrole
    if( exists($CastRoles{ $Member->{role} } ))
    {
       	$CastRoleId = $CastRoles{ $Member->{role} };
    } else {
       	print STDERR "Unknown role type $Program->{role}\n";
    }

    if( $GenericSQL{PROGRAMCAST}->{SELECT}->execute( Convert($Member->{givenname}), Convert($Member->{surname}), $CastRoleId, $Program->{program_tmsid} ) &&
        ($GenericSQL{PROGRAMCAST}->{SELECT}->fetchrow_arrayref()))
    {
	#all crew info is already in the database
    } else {

	#find or insert crew
    	if( $GenericSQL{CREW}->{SELECT}->execute( Convert($Member->{givenname}),
						Convert($Member->{surname}) ) &&
        	( $row = $GenericSQL{CREW}->{SELECT}->fetchrow_arrayref() ))
    	{
        	$CrewId = $row->[0];
    	} else {
        	$GenericSQL{CREW}->{INSERT}->execute(
			Convert($Member->{givenname}),
			Convert($Member->{surname} ) );
        
		if( $GenericSQL{CREW}->{SELECT}->execute(
			Convert($Member->{givenname}),
			Convert($Member->{surname} ) ) &&
            		( $row = $GenericSQL{CREW}->{SELECT}->fetchrow_arrayref() ))
        	{
            		$CrewId = $row->[0];
        	}
	}

	if( $GenericSQL{PROGRAMCAST}->{INSERT}->execute(
		$CrewId, $CastRoleId,
		$Program->{program_tmsid} ) ) 
	{
		$Updated = 1;
    	} else {
        	print STDERR "Failed insert on ProgramCast\n";
	}

    }
    return $Updated;
}
sub HandleProgram( $ )
{
    my $Program = shift();
    my $Record;
    my $MpaaId;
    my $StarId;
    my $ShowType;

    my $SeriesTiVoId;
    if( $Program->{program_tmsid} =~ /^EP(......)/ )
    {
        $SeriesTiVoId = int($1) + 212000000;
    }
    elsif( $Program->{program_tmsid} =~ /^MV(......)/ )
    {
        $SeriesTiVoId = int($1) + 213000000;
    }
    elsif( $Program->{program_tmsid} =~ /^SH(......)/ )
    {
        $SeriesTiVoId = int($1) + 214000000;
    }
    elsif( $Program->{program_tmsid} =~ /^SP(......)/ )
    {
        $SeriesTiVoId = int($1) + 215000000;
    }
    else
    {
        print STDERR "Unknown ProgramType for id $Program->{program_tmsid}\n";
        $SeriesTiVoId = 216000000;
    }
    if( !defined( $Program->{series_id} ) )
    {
        if( substr( $Program->{program_tmsid}, 0, 2 ) eq "MV" )
        {
            $Program->{series_id} = substr( $Program->{program_tmsid}, 0, 8 );
        }
    }
    HandleSeries( $Program->{series_id}, $SeriesTiVoId, $Program->{program_title} );
    if( defined( $Program->{mpaaRating} ) )
    {
        if( $GenericSQL{MPAA}->{SELECT}->execute( $Program->{mpaaRating} ) &&
            ($Record = $GenericSQL{MPAA}->{SELECT}->fetchrow_hashref()) &&
            ($MpaaId = $Record->{mpaarating_id}) )
        {
            delete $Program->{mpaaRating};
        } else {
            print STDERR "Unknown MpaaRating $Program->{mpaaRating}\n";
        }
    }
    if( defined( $Program->{starRating} ) )
    {
        if( $GenericSQL{STAR}->{SELECT}->execute( $Program->{starRating} ) &&
            ($Record = $GenericSQL{STAR}->{SELECT}->fetchrow_hashref()) &&
            ($StarId = $Record->{starrating_id}) )
        {
            delete $Program->{starRating};
        } else {
            print STDERR "Unknown StarRating $Program->{starRating}\n";
        }
    }
    if( defined( $Program->{showType} ) )
    {
        if( $GenericSQL{SHOWTYPE}->{SELECT}->execute( $Program->{showType} ) &&
            ($Record = $GenericSQL{SHOWTYPE}->{SELECT}->fetchrow_hashref() ))
        {
            $ShowType = $Record->{showtype_id};
            delete $Program->{showType};
        } else {
            print STDERR "Unknown showtype $Program->{showType}\n";
        }
    }
    if( !defined( $ProgTable{$Program->{program_tmsid}} ) )
    {
	if( !defined( $ProgTable{"LastID"} ) )
	{
	    $ProgTable{"LastID"} = 110000000;
	}
	$ProgTable{$Program->{program_tmsid}} = $ProgTable{"LastID"};
	$ProgTable{"LastID"} += 1;	   
    }

    if( $GenericSQL{PROGRAM}->{SELECT}->execute( $Program->{program_tmsid} ) &&
        ($Record = $GenericSQL{PROGRAM}->{SELECT}->fetchrow_hashref() ))
    {
	# Found a record; do comparisons
	if( (!defined($Program->{Updated}) || $Program->{Updated}==0) && 
	    TestAllFields( $Program, $Record ) )
	{
	    #print " All fields match\n";
	} else {
	    print "Updated Program\n";
            $GenericSQL{PROGRAM}->{UPDATE}->execute( 
					    Convert($Program->{program_title}),
					    Convert($Program->{program_subtitle}),
					    Convert($Program->{program_description}),
					    $Program->{syndicated_episode_number},
					    $Program->{original_air_date},
                                            $ShowType,
				     	    $ProgTable{$Program->{program_tmsid}},
                                            $Program->{series_id},
                                            $Program->{program_tmsid});
            if( substr($Program->{program_tmsid}, 0, 2) eq 'MV' )
            {
                $GenericSQL{MOVIE}->{UPDATE}->execute( $MpaaId,
                                                       $StarId,
                                                       $Program->{year},
                                                       $Program->{runTime},
                                                       $Program->{program_tmsid});
            }
        }
    } elsif ( defined($Program->{series_id}) && $GenericSQL{PROGRAM}->{INSERT1}->execute( $Program->{series_id},
                        $Program->{program_tmsid},
                        Convert($Program->{program_title}),
                        Convert($Program->{program_subtitle}),
                        Convert($Program->{program_description}),
                        $Program->{syndicated_episode_number},
                        $Program->{original_air_date},
                        $ShowType,
		        $ProgTable{$Program->{program_tmsid}}) ) 
    {
        if( substr($Program->{program_tmsid}, 0, 2) eq 'MV' )
        {
            $GenericSQL{MOVIE}->{INSERT}->execute(
                                                   $Program->{program_tmsid},
                                                   $MpaaId,
                                                   $StarId,
                                                   $Program->{year},
                                                   $Program->{runTime});
        }
    } elsif ( $GenericSQL{PROGRAM}->{INSERT2}->execute(
                        $Program->{program_tmsid},
                        Convert($Program->{program_title}),
                        Convert($Program->{program_subtitle}),
                        Convert($Program->{program_description}),
                        $Program->{syndicated_episode_number},
                        $Program->{original_air_date},
                        $ShowType,
		        $ProgTable{$Program->{program_tmsid}}) ) 
    {
        if( substr($Program->{program_tmsid}, 0, 2) eq 'MV' )
        {
            $GenericSQL{MOVIE}->{INSERT}->execute(
                                                   $Program->{program_tmsid},
                                                   $MpaaId,
                                                   $StarId,
                                                   $Program->{year},
                                                   $Program->{runTime});
        }
    } else {
	print STDERR "Execute failure\n";
    }
    
}

sub HandleGenre( $$$ )
{
    my $Genres = shift();
    my $Relevances = shift();
    my $Program = shift();
    my $row;
    my $Updated = 0;

    foreach my $Genre ( @{$Genres} )
    {
	next if ($Genre eq "Miniseries");
        my $GenreId;
	my $GenreRelevance = shift(@{$Relevances});
        if( $GenericSQL{PROGRAMGENRE}->{SELECT}->execute( $Program->{program_tmsid}, $Genre ) )
        {
            while( $row = $GenericSQL{PROGRAMGENRE}->{SELECT}->fetchrow_arrayref() )
            {
                $GenreId = $row->[0];
		if( defined($row->[1]) )
                {
		    #Program Genre found, does relevance need to be updated
		    if ($row->[1] != $GenreRelevance)
		    {
			$GenericSQL{PROGRAMGENRE}->{UPDATE}->execute( $GenreRelevance, $Program->{program_tmsid}, $GenreId ); 
			$Updated = 1;
		    }
                } elsif( $GenericSQL{PROGRAMGENRE}->{INSERT}->execute( $Program->{program_tmsid}, $GenreId, $GenreRelevance ) ) {
		    $Updated = 1;
                } else {
                    print STDERR "Failed ProgramGenre insert\n";
                }
            }
        } 
        if( !defined( $GenreId ) )
        {
            print STDERR "Unknown Genre $Genre\n";
        }
    }
    return $Updated;
}

sub HandleAdvisory( $$ )
{
    my $Advisories = shift();
    my $Program = shift();
    my $row;

    foreach my $Advisory ( @{$Advisories} )
    {
        my $AdvisoryId;
        if( $GenericSQL{ADVISORY}->{SELECT}->execute( $Advisory ) )
        {
            while( $row = $GenericSQL{ADVISORY}->{SELECT}->fetchrow_hashref() )
            {
                $AdvisoryId = $row->{advisory_id};
                if( $GenericSQL{PROGRAMADVISORY}->{SELECT}->execute( $Program->{program_tmsid}, $AdvisoryId )  &&
                    ($row = $GenericSQL{PROGRAMADVISORY}->{SELECT}->fetchrow_hashref() ))
                {
                    ;
                } elsif( $GenericSQL{PROGRAMADVISORY}->{INSERT}->execute( $Program->{program_tmsid}, $AdvisoryId ) ) {
		    $Program->{Updated} = 1;
                } else {
                    print STDERR "Failed ProgramAdvisory insert\n";
                }
            }
        } 
        if( !defined( $AdvisoryId ) )
        {
            print STDERR "Unknown Advisory $Advisory\n";
        }
    }
}

sub HandleMessage( $ )
{
    my $Message = shift();

    my $Destination = DESTINATION_MESSAGE_BOARD;
    if( $Message =~ /^Your subscription will expire: (.*)/ )
    {
        my $ExpireDate = Time::Piece->strptime($1, '%Y-%m-%dT%H:%M:%SZ')->epoch() / 86400;
        if( $ExpireDate < $CurrentDay + 7 )
        {
            # PTCM if sub expires within 1 week
            $Destination = DESTINATION_PRE_TIVO_CENTRAL;
        }
    }

    InsertMessage( $Message, $Destination );
    if( $Destination == DESTINATION_PRE_TIVO_CENTRAL ) {
	# Every PTCM should also go to the MessageBoard
        InsertMessage( $Message, DESTINATION_MESSAGE_BOARD );
    }
}

sub InsertMessage( $$ )
{
    my( $Message, $Destination ) = @_;

    my $Subject = "DataDirect Message";
    my $Sender = "ddparser";
    my $ExpirationDay = $CurrentDay + 5;

    if( $GenericSQL{MESSAGES}->{SELECT}->execute( $Message, $Destination ) &&
        ( $GenericSQL{MESSAGES}->{SELECT}->fetchrow_hashref() ))
    {
        ; # This exact message/destination already exists
    } else {
        if( ! $GenericSQL{MESSAGES}->{INSERT}->execute( $Subject,
                                                       $Sender,
						       $Message,
						       PRIORITY_MEDIUM,
						       $ExpirationDay,
						       $Destination,
						       $ValidTime ) ) {
            print STDERR "Failed Message insert: ($Destination) $Message\n";
        }
    }
}

sub TestAllFields( $$ )
{
    my $First = shift();
    my $Second = shift();
    my $RetCode = 1;

    foreach my $Field ( keys ( %{$First} ) )
    {
	next if( $Field =~ /_ver$/ );
	next if( $Field eq 'runTime' );    # in Programs for MovieInfo
	next if( $Field eq 'year' );       # in Programs for MovieInfo
	if( defined( $First->{$Field} ) && defined( $Second->{$Field} ) )
	{
	    if( Convert($First->{$Field}) ne $Second->{$Field} ) 
	    {
	        $RetCode = 0;
	        printf " Field mismatch $Field:[%s][%s]\n", Convert($First->{$Field}), $Second->{$Field};
	    }
	}
	elsif ( !defined( $First->{$Field} ) && !defined( $Second->{$Field} ) )
	{
	}
	elsif ( defined( $First->{$Field} ) )
	{
	    $RetCode = 0;
	    printf " Field mismatch $Field:[%s][]\n", Convert($First->{$Field});
	}
	#else don't override an existing value with a NULL
    }
    return $RetCode;
}

sub GetTivoPostalCodeAndLocation( $$ )
{
    my ($postalcode, $lineup_type) = @_;
    my ($TivoPostalCode, $PostalLocation);

    $TivoPostalCode = $postalcode;
    $TivoPostalCode =~ s/[A-Z]/0/g;
    if( $lineup_type eq 'Satellite' )
    {
        $PostalLocation = substr($TivoPostalCode, 0, 2);
        $TivoPostalCode = 'DBS';
    } else {
        $PostalLocation = '';
        $TivoPostalCode = substr($TivoPostalCode, 0, 5);
    }
    ($TivoPostalCode, $PostalLocation);
}

sub FlagPostalCodeForUpdate( $$ )
{
    my ($postalcode, $lineup_type) = @_;
    my ($TivoPostalCode, $PostalLocation) = GetTivoPostalCodeAndLocation( $postalcode, $lineup_type );


    my $PostalCodeWithLocation =  $TivoPostalCode;
    $PostalCodeWithLocation = $PostalCodeWithLocation.'~'.$PostalLocation if ($PostalLocation ne "");
    $PostalCodesNeedingUpdate{$PostalCodeWithLocation} = 1;
}

sub IncrementPostalCodeVer( )
{
    my ($key, $TivoPostalCode, $PostalLocation, $sql);
    foreach $key (keys %PostalCodesNeedingUpdate) {
        ($TivoPostalCode, $PostalLocation) = split('~', $key);
	$PostalLocation = "" if (!defined($PostalLocation));

        $sql = $GenericSQL{POSTALCODE}->{SELECT};
        if( $sql->execute($TivoPostalCode, $PostalLocation) && $sql->fetchrow_hashref() )
        {
            $GenericSQL{POSTALCODE}->{UPDATE}->execute( $TivoPostalCode, $PostalLocation );
        } else {
            $GenericSQL{POSTALCODE}->{INSERT}->execute( $TivoPostalCode, $PostalLocation );
        }
    }
}

sub UpdateProgramsSeriesTivoId( )
{
    $GenericSQL{PROGRAMS}->{UPDATESERIESTIVOID}->execute();
    $GenericSQL{PROGRAMS}->{UPDATESERIESTIVOID2}->execute();
}

sub HandleLineup( $ )
{
    my $Lineup = shift();
    my $LineupId;
    my $row;
    my $Updated = 0;
    my $StationCount = 0;

    my($ret,$sql);
    if (!defined($Lineup->{device})) {
	$sql = $GenericSQL{LINEUP}->{SELECTNULL};
	$ret = $sql->execute($Lineup->{tmsid},$Lineup->{name},$Lineup->{type},$Lineup->{postal});
    } else {
	    $sql = $GenericSQL{LINEUP}->{SELECT};
	    $ret = $sql->execute($Lineup->{tmsid},$Lineup->{name},$Lineup->{type},$Lineup->{device},$Lineup->{postal});
    }
    if($ret &&
        ( $row = $sql->fetchrow_hashref() ))
    {
        $LineupId = $row->{lineup_id};
	if ( $Lineup->{tmsid} && !$row->{lineup_tmsid} )
	{
		#tmsids don't match, probably upgrading from NULL
		$Updated = 1;
	}

    } else {
	my ($TivoPostalCode, $PostalLocation) = GetTivoPostalCodeAndLocation( $Lineup->{postal}, $Lineup->{type} );
        print " New lineup \n";
        $GenericSQL{LINEUP}->{INSERT}->execute( $Lineup->{tmsid},
						$Lineup->{name},
                                                $Lineup->{type},
                                                $Lineup->{device},
                                                $Lineup->{postal},
						$TivoPostalCode,
						$PostalLocation,
						$Lineup->{location} );
	FlagPostalCodeForUpdate($Lineup->{postal}, $Lineup->{type});
	if (!defined($Lineup->{device})) {
	$sql = $GenericSQL{LINEUP}->{SELECTNULL};
	$ret = $sql->execute($Lineup->{tmsid},$Lineup->{name},$Lineup->{type},$Lineup->{postal});
    } else {
	    $sql = $GenericSQL{LINEUP}->{SELECT};
	    $ret = $sql->execute($Lineup->{tmsid},$Lineup->{name},$Lineup->{type},$Lineup->{device},$Lineup->{postal});
    }
    	if ($ret &&
            ( $row = $sql->fetchrow_hashref() ) )
        {
            $LineupId = $row->{lineup_id};
        } else {
            print STDERR "Failed to insert lineup $Lineup->{name}\n";
            return;
        }
    }
    foreach my $Station ( @{$Lineup->{stations}} )
    {
        if( $GenericSQL{LINEUPMAP}->{SELECT1}->execute( $LineupId, $Station->{station_id}, $Station->{channel_num} ) )
        {
            my $row;
            my $Idx = 0;
            while( $row = $GenericSQL{LINEUPMAP}->{SELECT1}->fetchrow_hashref() )
            {
                $Idx++;
                if( $Station->{channel_num} == $row->{channel_num} )
                {
                } else {
                    print "changed channel assignment for $Station->{station_id}\n";
                    $Updated = 1;
                }
            }
            if( $Idx == 0 )
            {
                print STDERR "Didn't find Station $Station->{station_id}:$Station->{channel_num} in lineup $LineupId\n";
                $Updated = 1;
            }
        } else {
            $Updated = 1;
        }
    }
    if( $GenericSQL{LINEUPMAP}->{SELECT2}->execute( $LineupId ) )
    {
        while( $row = $GenericSQL{LINEUPMAP}->{SELECT2}->fetchrow_hashref() )
        {
            $StationCount++;
        }
    }
    if( $Updated ||
        ($StationCount != scalar( @{$Lineup->{stations}} ) ) )
    {
        $GenericSQL{LINEUPMAP}->{DELETE}->execute( $LineupId );
        foreach my $Station ( @{$Lineup->{stations}} )
        {

            $GenericSQL{LINEUPMAP}->{INSERT}->execute( $LineupId,
                                                       $Station->{station_id},
                                                       $Station->{channel_num},
                                                       $Station->{from},
                                                       $Station->{to} );
        }
        print " Changed lineup \n";
        $GenericSQL{LINEUP}->{UPDATE}->execute( $Lineup->{tmsid},
						$Lineup->{name},
                                                $Lineup->{type},
                                                $Lineup->{device},
                                                $Lineup->{postal},
						$Lineup->{location},
                                                $LineupId );
	FlagPostalCodeForUpdate($Lineup->{postal}, $Lineup->{type});
    }

}
sub end_element {
    my( $self, $properties ) = @_;

#    my $element = $properties->{'Name'};
#    my %attrs = %{$properties->{'Attributes'}};

    if( $TagStack[0] eq 'message' ) {
	HandleMessage($Accumulator);
    } elsif($TagStack[0] eq 'callSign') {
	$CurStation{callsign} = $Accumulator;
    } elsif(($TagStack[0] eq 'name') && ($TagStack[1] eq 'station')) {
	$CurStation{name} = $Accumulator;
    } elsif(($TagStack[0] eq 'affiliate') && ($TagStack[1] eq 'station')) {
	$CurStation{affiliate} = $Accumulator;
    } elsif(($TagStack[0] eq 'station') && ($TagStack[1] eq 'stations')) {
	#%{$Stations{$CurStation{station_id}}} = %CurStation;
	HandleStation( \%CurStation );
    } elsif ( $TagStack[0] eq 'lineup' ) {
        HandleLineup( \%CurLineup );
    } elsif(($TagStack[0] eq 'title') && ($TagStack[1] eq 'program')){
	$CurProgram{program_title} = $Accumulator;
	# I DON'T THINK SERIES IS USED!!!!
#	if(!defined( $Series{$CurProgram{Series}}->{Title} ) )
#	{
#	    $Series{$CurProgram{Series}}->{Title} = $Accumulator;
#	}
    } elsif(($TagStack[0] eq 'subtitle') && ($TagStack[1] eq 'program')){
	$CurProgram{program_subtitle} = $Accumulator;
    } elsif(($TagStack[0] eq 'showType') && ($TagStack[1] eq 'program')){
	$CurProgram{showType} = $Accumulator;
    } elsif(($TagStack[0] eq 'series') && ($TagStack[1] eq 'program')){
	if(length $Accumulator > 0)
	{
	    $CurProgram{series_id} = $Accumulator;
	}
    } elsif(($TagStack[0] eq 'description') && ($TagStack[1] eq 'program')){
	$CurProgram{program_description} = $Accumulator;
    } elsif(($TagStack[0] eq 'syndicatedEpisodeNumber') && ($TagStack[1] eq 'program')){
	$Accumulator =~ s/[^0-9]//g;
	$CurProgram{syndicated_episode_number} = $Accumulator;
    } elsif(($TagStack[0] eq 'originalAirDate') && ($TagStack[1] eq 'program')){
	$CurProgram{original_air_date} = Time::Piece->strptime($Accumulator, '%Y-%m-%d')->epoch() / 86400;
    } elsif(($TagStack[0] eq 'mpaaRating') && ($TagStack[1] eq 'program')){
	$CurProgram{mpaaRating} = $Accumulator;
    } elsif(($TagStack[0] eq 'starRating') && ($TagStack[1] eq 'program')){
	$CurProgram{starRating} = $Accumulator;
    } elsif(($TagStack[0] eq 'year') && ($TagStack[1] eq 'program')){
	$CurProgram{year} = $Accumulator;
    } elsif(($TagStack[0] eq 'colorCode') && ($TagStack[1] eq 'program')){
#	$CurProgram{colorCode} = $Accumulator;
	# Not used yet, so don't store
    } elsif(($TagStack[0] eq 'runTime') && ($TagStack[1] eq 'program')){
	if( $Accumulator =~  /^PT([0-9]{2})H([0-9]{2})M$/)
	{
	    my $Hours = $1;
	    my $Min = $2;
	    $CurProgram{runTime} = $Hours*60 + $Min;
	}
    } elsif(($TagStack[0] eq 'advisory') && ($TagStack[1] eq 'advisories')) {
	push @{$CurProgram{advisories}}, $Accumulator;
    } elsif( $TagStack[0] eq 'advisories' ) {
	if( defined( $CurProgram{advisories} ) )
	{
	    HandleAdvisory( $CurProgram{advisories}, \%CurProgram );
	    delete $CurProgram{advisories};
	}
    } elsif( $TagStack[0] eq 'program' ) {
	HandleProgram( \%CurProgram );
    } elsif( $TagStack[0] eq 'schedule' ) {
        HandleSchedule( \%CurSched );
    } elsif(($TagStack[0] eq 'class') && ($TagStack[1] eq 'genre')) {
	push @{$CurProgram{genre}}, $Accumulator;
    } elsif(($TagStack[0] eq 'relevance') && ($TagStack[1] eq 'genre')) {
	push @{$CurProgram{relevance}}, $Accumulator;
    } elsif( $TagStack[0] eq 'programGenre' ) {
	if( defined( $CurProgram{genre} ) )
	{
	    my $Updated = HandleGenre( $CurProgram{genre}, $CurProgram{relevance}, \%CurProgram );
	    if ($Updated)
	    {
	        if ($GenericSQL{PROGRAM}->{UPDATED}->execute($CurProgram{program_tmsid}, $ValidTime))
		{
	            print "Program genre updated $CurProgram{program_tmsid}\n";
	        }
	    }
	}
    } elsif((($TagStack[0] eq 'givenname') ||
	     ($TagStack[0] eq 'surname') ||
	     ($TagStack[0] eq 'role')) &&
	    ($TagStack[1] eq 'member'))
    {
	my $Tag;
	$Tag = $TagStack[0];
 	$Tag =~ s/ /_/g;
	$CurMember{$Tag} = $Accumulator;
    } elsif($TagStack[0] eq 'member') {
	$CurrentCrewUpdated += HandleCrew( \%CurMember, \%CurProgram );
    } elsif($TagStack[0] eq 'crew') {
	if ($CurrentCrewUpdated)
	{
	    if ($GenericSQL{PROGRAM}->{UPDATED}->execute($CurProgram{program_tmsid}, $ValidTime))
	    {
	        print "Program crew updated $CurProgram{program_tmsid}\n";
	        $CurrentCrewUpdated = 0;
	    }
	}
    } elsif ( $TagStack[0] eq 'stations' ) {
        debugprint(0, sprintf("Parsed stations %d sec\n", time() - $Start));
    } elsif ( $TagStack[0] eq 'lineups' ) {
        debugprint(0, sprintf("Parsed lineups %d sec\n", time() - $Start));
    } elsif ( $TagStack[0] eq 'schedules' ) {
        debugprint(0, sprintf("Parsed schedules %d sec\n", time() - $Start));
    } elsif ( $TagStack[0] eq 'programs' ) {
        debugprint(0, sprintf("Parsed programs %d sec\n", time() - $Start));
    } elsif ( $TagStack[0] eq 'productionCrew' ) {
        debugprint(0, sprintf("Parsed productionCrew %d sec\n", time() - $Start));
    } elsif ( $TagStack[0] eq 'genres' ) {
        debugprint(0, sprintf("Parsed genres %d sec\n", time() - $Start));
    }

    if( !defined( $TagStack[0] ))
    {
	print "[$TagStack[1]:$TagStack[0]]\n";
    }

    shift @TagStack;
    $Accumulator='';
}

sub characters {
    my( $self, $data ) = @_;
    
    $Accumulator .= $data;
}

sub findit($$)
{
    my $value = shift();
    my $enum_list = shift();

    my @enum = map qr/^(?:$_)$/i, @{$enum_list};
    printf STDERR "Size: %d\n", scalar(@enum);
    for (my $i = 0; $i < scalar(@enum); $i++) {
        if ($value =~ $enum[$i])
        {
            return $i + 1;
        }
    }
    return undef;
}

sub MpaaRating($)
{
    my @enum_list =     (
     'g',
     'pg',
     'pg13|pg-13',
     'r',
     'x',
     'nc|nc17|nc-17',
     'ao',
     'nr',
    );
    return( findit(shift(), \@enum_list) );
}
sub StarRating($)
{
    my @enum_list =    (
     '\*|one',
     '\*\s*\+|1/2|one\s*point\s*five',
     '\*{2}|two',
     '\*{2}\s*\+|1/2|two\s*point\s*five',
     '\*{3}|three',
     '\*{3}\s*\+|1/2|three\s*point\s*five',
     '\*{4}|four',
    );

    return( findit(shift(), \@enum_list) );
}
sub ShowType($)
{
    my @enum_list = (
        'serial',
        'short film',
        'special',
        'limited series',
        'series|miniseries',
        'paid programming', );
    return( findit( shift, \@enum_list ) );
};

sub Advisory($)
{
    my @enum_list =    (
     'language',
     'graphic language',
     'nudity',
     'brief nudity',
     'graphic violence',
     'violence',
     'mild violence',
     'strong sexual content',
     'rape',
     'adult situations',
    );

    return( findit(shift(), \@enum_list) );
}


sub debugprint()
{
    my $Debuglvl = shift;
    my $String   = shift;
    if( $Verbose > $Debuglvl )
    {
        print $String;
    }
}



my $iIdx = 0;

# Process Headend
my $Version = 309;
my $HeVersion = 309;

# Update the versions for the PostalCodes that have changed
IncrementPostalCodeVer();

UpdateProgramsSeriesTivoId();
