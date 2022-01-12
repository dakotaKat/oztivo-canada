#!/usr/bin/perl
#
#  $Id: mkPrograms.pl,v 1.24 2004/09/12 16:05:50 dboardman Exp $
#

use strict;

use FindBin qw($Bin);
use Getopt::Long;

use DBI;
use Data::Dumper;
use Config::IniFiles 2.37;
use POSIX qw(strtod);

# Switch to this program's directory
chdir($Bin);

my $Verbose = 0;

GetOptions( 'verbose:i'       => \$Verbose,
            'v:i'             => \$Verbose
);

sub getnum {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    $! = 0;
    my($num, $unparsed) = strtod($str);
    if (($str eq '') || ($unparsed != 0) || $!) {
        return undef;
    } else {
        return $num;
    } 
} 

sub is_numeric { defined getnum($_[0]) }

my ($cfg,$cfg_stations);

sub cfg_SectionExists ($) {
	my($section) = @_;
	my($ret) = 0;
	if (defined($cfg_stations)) {
		$ret = $cfg_stations->SectionExists($section);
	}
	$ret = $cfg->SectionExists($section) if ($ret == 0);
	return $ret;
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

my $fn = "config.ini";
if (! -e $fn) { 
	print STDERR "Missing $fn file\n";
	print STDERR "Creating...\n";
	open(F,">$fn");
	print F <<EOFCONFIG;
[base]
version=1

[default]
community=Toronto
city=Toronto
county=York
state=ON
country=Canada
location=Toronto
timezone=1
EOFCONFIG
	close(F);
}

$cfg = new Config::IniFiles(-file=>$fn,-nocase=>1);
if (!defined($cfg)) {
	my($i);
	for $i (0..$#Config::IniFiles::errors) {
		print STDERR $Config::IniFiles::errors[$i],"\n";
	}
	exit(1);
}

my $cfg_State = cfg_val("default","state","ON");
my $ListingsTextfileDir = './listings';

our $Database = "tvdata";
our $dBUser = 'dbuser';
our $dBPassword = 'dbpassword';
our $ConnectionStr = "dbi:mysql:$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my $Start;

my $ValidTime = $ARGV[0];
my $CurrentTime = time();
my $CurrentDay = $CurrentTime / 86400;
$CurrentDay =~ s/\..*$//;
$CurrentTime -= $CurrentDay * 86400;
my %GenericSQL;

$GenericSQL{LINEUPS}->{SELECT} = $connection->prepare("SELECT * FROM Lineups");
$GenericSQL{LINEUP}->{SELECT} = $connection->prepare("SELECT * FROM Lineup_map WHERE lineup_id=?");
$GenericSQL{STATION}->{SELECT} = $connection->prepare("SELECT * FROM Stations WHERE station_id=? ORDER BY station_tivo_id"); 

$GenericSQL{MPAA}->{SELECT} = $connection->prepare("SELECT * FROM MpaaRatings WHERE mpaarating_id=?");
$GenericSQL{STAR}->{SELECT} = $connection->prepare("SELECT * FROM StarRatings WHERE starrating_id=?");
$GenericSQL{TVRATING}->{SELECT} = $connection->prepare("SELECT * FROM TvRatings WHERE tvrating_id=?");
$GenericSQL{STATION}->{SELECT} = $connection->prepare("SELECT * FROM Stations WHERE station_id=?");

$GenericSQL{SERIES}->{SELECT} = $connection->prepare("SELECT DISTINCT Series.series_id, Series.series_ver, Series.series_title, Series.series_tivoid FROM Schedule,Programs,Series WHERE Programs.program_tmsid = Schedule.program_tmsid AND Programs.series_tivoid = Series.series_tivoid AND schedule_day >= ? AND valid >= ?"); 
$GenericSQL{PROGRAMS}->{SELECT} = $connection->prepare("SELECT DISTINCT Programs.*, Series.series_title FROM Schedule,Programs,Series WHERE Programs.program_tmsid = Schedule.program_tmsid AND Programs.series_tivoid = Series.series_tivoid AND schedule_day >= ? AND valid >= ?");

$GenericSQL{GENRE}->{SELECT} = $connection->prepare("SELECT * FROM ProgramGenre, Genres WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{GENRE}->{SELECT2} = $connection->prepare("SELECT tivogenre,genre FROM ProgramGenre, Genres, Programs WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid = Programs.program_tmsid AND Programs.series_id=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{GENRE}->{SELECT3} = $connection->prepare("SELECT tivogenre,genre FROM ProgramGenre, Genres, Programs WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid = Programs.program_tmsid AND Programs.program_title=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{ADVISORY}->{SELECT} = $connection->prepare("SELECT * FROM ProgramAdvisories, Advisories WHERE ProgramAdvisories.advisory_id = Advisories.advisory_id AND ProgramAdvisories.program_tmsid=?");

$GenericSQL{CREW}->{SELECT} = $connection->prepare("SELECT * FROM ProgramCast, Crew, CastRoles WHERE ProgramCast.castrole_id=CastRoles.castrole_id AND ProgramCast.crew_id = Crew.crew_id AND ProgramCast.program_tmsid=?");

$GenericSQL{SCHEDULE}->{SELECT1} = $connection->prepare("SELECT DISTINCT schedule_day, station_id FROM Schedule WHERE schedule_day >= ? AND valid >= ? ORDER BY schedule_day, station_id" );
$GenericSQL{SCHEDULE}->{SELECT2} = $connection->prepare("SELECT * FROM Schedule,Lineup_map,Programs WHERE Schedule.station_id = Lineup_map.station_id AND Programs.program_tmsid = Schedule.program_tmsid AND Lineup_map.lineup_id = ? AND schedule_day=? AND Schedule.station_id=? AND valid >= ? ORDER BY schedule_time" );
$GenericSQL{SCHEDULE}->{DELETE} = $connection->prepare("DELETE FROM Schedule WHERE schedule_day < ?");

$GenericSQL{STATIONDAYVER}->{SELECT} = $connection->prepare("SELECT * FROM StationDayVer WHERE schedule_day=? AND station_id=?" );
$GenericSQL{STATIONDAYVER}->{INSERT} = $connection->prepare("INSERT INTO StationDayVer( schedule_day, station_id, version ) VALUES ( ?,?,1 )" );
$GenericSQL{STATIONDAYVER}->{UPDATE} = $connection->prepare("UPDATE StationDayVer SET version = version+1 WHERE schedule_day=? AND station_id=?" );
$GenericSQL{STATIONDAYVER}->{DELETE} = $connection->prepare("DELETE FROM StationDayVer WHERE schedule_day < ?");
$GenericSQL{MOVIEINFO}->{SELECT} = $connection->prepare("SELECT * FROM MovieInfo WHERE program_tmsid=?");

$GenericSQL{MESSAGES}->{SELECT} = $connection->prepare("SELECT * FROM Messages WHERE valid >= ?" );
$GenericSQL{MESSAGES}->{DELETE} = $connection->prepare("DELETE FROM Messages WHERE expiration_day < ?");

sub FindMpaa( $ )
{
    my $MpaaId = shift();
    my $row;
    if( defined( $MpaaId ) &&
	$GenericSQL{MPAA}->{SELECT}->execute( $MpaaId ) &&
	($row = $GenericSQL{MPAA}->{SELECT}->fetchrow_hashref()) )
    {
	return $row->{tivorating};
    } 
    return undef;
}
sub FindStar( $ )
{
    my $StarId = shift();
    my $row;
    if( defined( $StarId ) &&
	$GenericSQL{STAR}->{SELECT}->execute( $StarId ) &&
	($row = $GenericSQL{STAR}->{SELECT}->fetchrow_hashref()) )
    {
	return $row->{tivorating};
    } 
    return undef;
}
sub HandleMovieExtras( $ )
{
    my $ProgramTmsId = shift();
    my $row;
    my $RetVal = "";
    if( $GenericSQL{MOVIEINFO}->{SELECT}->execute( $ProgramTmsId ) &&
	($row = $GenericSQL{MOVIEINFO}->{SELECT}->fetchrow_hashref()) )
    {
	my $MpaaRating = FindMpaa( $row->{mpaarating_id} );
	my $StarRating = FindStar( $row->{starrating_id} );
	if( defined( $MpaaRating ) )
	{
	    $RetVal .= "\tMpaaRating: $MpaaRating\n";
	}
	if( defined( $StarRating ) )
	{
	    $RetVal .= "\tStarRating: $StarRating\n";
	}
	if( defined( $row->{year} ) )
	{
	    $RetVal .= "\tMovieYear: $row->{year}\n";
	}
	if( defined( $row->{runtime} ) )
	{
	    $RetVal .= "\tMovieRunTime: $row->{runtime}\n";
	}
    }

    return $RetVal;

}

sub FindTivoStationId ( $ )
{
    my $InVal = shift();
    my $row;
    if( $GenericSQL{STATION}->{SELECT}->execute( $InVal ) &&
        ($row = $GenericSQL{STATION}->{SELECT}->fetchrow_hashref() ) )
    {
        return $row->{station_tivo_id};
    }
    print STDERR "Failed to find TivoId for [$InVal]\n";
    return undef;
}

sub FindTvRating( $ )
{
    my $RetCode;
    my $InRating = shift();
    my $row;
    if( !defined ($InRating ) )
    {
        return undef;
    }
    if( $GenericSQL{TVRATING}->{SELECT}->execute( $InRating ) &&
        ($row = $GenericSQL{TVRATING}->{SELECT}->fetchrow_hashref() ))
    {
        return $row->{tivorating};
    } 
    print STDERR "Didn't find TvRating $InRating\n";
    return undef;
}
sub GetStationDayVer( $$ )
{
    my $RetVal = 1;
    my $Day = shift();
    my $Station = shift();
    my $row;
    if( $GenericSQL{STATIONDAYVER}->{SELECT}->execute( $Day, $Station ) &&
	($row = $GenericSQL{STATIONDAYVER}->{SELECT}->fetchrow_hashref()))
    {
	$RetVal = $row->{version};
	$GenericSQL{STATIONDAYVER}->{UPDATE}->execute( $Day, $Station );
    } elsif ( $GenericSQL{STATIONDAYVER}->{INSERT}->execute( $Day, $Station ) ){
    }
    return $RetVal;

}
sub GetRepeat( $$$ )
{
    my $RetVal = 0;
    my ($ProgramType, $OriginalAirDate, $ShowTypeId) = @_;
    if (defined $OriginalAirDate)
    {
        if (($ProgramType eq "EP")
		|| (($ProgramType eq "SH") && ($ShowTypeId == 2 || $ShowTypeId == 3)))
        {
	    # Use 14 day rule
            if ($CurrentDay - $OriginalAirDate > 14)
            {
                $RetVal = 1;
            }
        }
    }
    return $RetVal;
}

sub GetDontIndex($)
{
	my $program_tmsid = shift;
	if ($program_tmsid eq "SH0000010000" # Paid Progamming
	 || $program_tmsid eq "SH0191120000" # SIGN OFF
	 || $program_tmsid eq "SH0191630000" # SIGN ON
	 || $program_tmsid eq "SH0191680000" # To Be Announced
	 || $program_tmsid eq "SH0263440000" # Pay-Per-View Previews
	 || $program_tmsid eq "SH1453390000" # Pay-Per-View
	 || $program_tmsid eq "SH2992650000" # TV Guide
	 || $program_tmsid eq "SH3244310000" # NBA League Pass
         || $program_tmsid eq "SH3244340000" # NHL Center Ice
         || $program_tmsid eq "SH3244350000" # MLB Extra Innings
         || $program_tmsid eq "SH3244360000" # ESPN GamePlan
         || $program_tmsid eq "SH3244370000" # ESPN Full Court
         || $program_tmsid eq "SH3244380000" # MLS Shootout
	 # NFL Sunday Ticket
	 # Mega March Mania
         || $program_tmsid eq "SH3449980000") # News" (Chinese channel)
	{
		return 1;
	} else {
		return 0;
	}
}
##########################################
##########################################
##########################################


sub HandleShowType( $ )
{
    my $Id = shift;
    return $Id;
}

sub PrintGenres( $$;$ )
{
    my $RetVal = "";
    my ($SeriesTitle, $ProgramTmsId, $SeriesId) = @_;

    my $row;
    my $SQL;
    if( defined( $ProgramTmsId ) )
    {
	$SQL = $GenericSQL{GENRE}->{SELECT};
	$SQL->execute( $ProgramTmsId );
    } elsif (defined($SeriesId) && ($SeriesId ne "")) {
	$SQL = $GenericSQL{GENRE}->{SELECT2};
	$SQL->execute( $SeriesId );
    } else {
	$SQL = $GenericSQL{GENRE}->{SELECT3};
	$SQL->execute( $SeriesTitle );
    }

    while( $row = $SQL->fetchrow_hashref() )
    {
	if( defined( $row->{tivogenre} ) )
	{
	    $RetVal .= "\tGenre: $row->{tivogenre}\n";
	} else {
	    print STDERR "Unknown tivogenre $row->{genre}\n";
	}
    }
    if( $SeriesId =~ /^MV/ )
    {
	$RetVal .= "\tGenre: 1006\n";
    }

    return $RetVal;
}
################################
################################
################################

if (! -e $ListingsTextfileDir)
{
    print STDERR "Missing $ListingsTextfileDir directory\n";
    print STDERR "Creating...\n";
    mkdir $ListingsTextfileDir;
}
else
{
    # remove old listings text files so that the entire dir can be copied/gzipped into the slice directory
    unlink(<$ListingsTextfileDir/*-[0-9][0-9][0-9][0-9][0-9].txt>);
}

my $AllEndDay = $CurrentDay;

$GenericSQL{LINEUPS}->{SELECT}->execute();
my ($LineupRow, $HeadendId, $HeadendPostal);
while( $LineupRow = $GenericSQL{LINEUPS}->{SELECT}->fetchrow_hashref() )
{
    $Start = time();

    if ($LineupRow->{lineup_tmsid})
    {
        $HeadendId = $LineupRow->{lineup_tmsid};
        $HeadendId =~ s/\:.$//;
        $HeadendId =~ s/[:\-]//g;
    } else {
        if( $LineupRow->{lineup_type} eq 'Satellite' )
        {
            $HeadendPostal = 'DBS';
        } else {
            $HeadendPostal = substr($LineupRow->{lineup_postalcode}, 0, 5);
            $HeadendPostal =~ s/[^0-9]/0/g;
	}
        $HeadendId = "$cfg_State$HeadendPostal$LineupRow->{lineup_id}";
    }
    print "$HeadendId\n";

    my $EndDay = $CurrentDay;
    open DATA, "> $ListingsTextfileDir/$HeadendId-$CurrentDay.txt";

    print DATA "Guide type=3\n\n";

    if( $GenericSQL{SCHEDULE}->{SELECT1}->execute( $CurrentDay, $ValidTime ) )
    {
	my $row;
	my @Schedule;
	while( $row = $GenericSQL{SCHEDULE}->{SELECT1}->fetchrow_hashref() )
	{
	    push @Schedule, { day => $row->{schedule_day},
			      station => $row->{station_id} };
	}
	foreach my $StationDay ( @Schedule )
	{
	    if( $GenericSQL{SCHEDULE}->{SELECT2}->execute(
				$LineupRow->{lineup_id},
				$StationDay->{day},
				$StationDay->{station}, $ValidTime ) )
	    {
		if( $StationDay->{day} > $EndDay )
		{
		    $EndDay = $StationDay->{day};
		    if( $EndDay > $AllEndDay )
		    {
		        $AllEndDay = $EndDay;
	            }
	        }
		my $TivoStation = FindTivoStationId( $StationDay->{station} );
		my $StationDayId = sprintf("%d%03d",
					   substr($TivoStation, -5) + 300000,
					   substr($StationDay->{day}, -3));
		my $Version = GetStationDayVer($StationDay->{day},
					       $StationDay->{station} ) ;
		my $iIdx = 10;
		#$iIdx += $Version * 48;
		my $FirstTime = 1;
		while( $row = $GenericSQL{SCHEDULE}->{SELECT2}->fetchrow_hashref() )
		{
		    if( $FirstTime )
		    {
			$FirstTime = 0;
			print DATA <<ENDHEAD
StationDay/1/$StationDayId/$Version {
	Station: Station/1/$TivoStation
	Day: $StationDay->{day}
ENDHEAD
			;
		    }
		    print DATA "	Showing: Showing/$iIdx\n";
		    $iIdx++;
		}
		if( !$FirstTime )
		{
		    $GenericSQL{SCHEDULE}->{SELECT2}->execute(
					$LineupRow->{lineup_id},
					$StationDay->{day},
					$StationDay->{station}, $ValidTime);
		    $iIdx = 10;
                    #$iIdx += $Version * 48;
		    while( $row = $GenericSQL{SCHEDULE}->{SELECT2}->fetchrow_hashref() )
		    {
			my $TiVoBits = 0;
			my $TiVoProgramId = $row->{program_tivoid};
			my $Repeat = $row->{repeat};
			if (!defined($Repeat))
			{
			    my $ProgramType = substr($row->{program_tmsid}, 0, 2);
			    $Repeat = GetRepeat($ProgramType, $row->{original_air_date}, $row->{showtype_id});
			}
			$TiVoBits |= 0x0001 if ( $row->{closecaption} );
			$TiVoBits |= 0x0002 if ( $row->{stereo} );
			$TiVoBits |= 0x0004 if ( $row->{subtitled} );
#			$TiVoBits |= 0x0008 if ( $JoinedInProgress );
#			$TiVoBits |= 0x0010 if ( $CableInTheClassroom );
#			$TiVoBits |= 0x0020 if ( $Sap );
#			$TiVoBits |= 0x0040 if ( $Blackout );
#			$TiVoBits |= 0x0080 if ( $Intercast );
#			$TiVoBits |= 0x0100 if ( $ThreeD );
			$TiVoBits |= 0x0200 if ( $Repeat );
			$TiVoBits |= 0x0400 if ( $row->{letterbox} );
			$TiVoBits |= 0x0800 if ( $row->{subtitled} );
			$TiVoBits |= 0x1000 if ( $row->{hdtv} );
#			$TiVoBits |= 0x10000 if ( $SexRating );
#			$TiVoBits |= 0x20000 if ( $ViolenceRating );
#			$TiVoBits |= 0x40000 if ( $LanguageRating );
#			$TiVoBits |= 0x80000 if ( $DialogRating );
#			$TiVoBits |= 0x100000 if ( $FvRating );

			my $TiVoStation = FindTivoStationId( $row->{station_id} );
			print DATA <<ENDSHOWING
	Subrecord Showing/$iIdx {
		Station: Station/1/$TiVoStation
		Program: Program/1/$TiVoProgramId
		Date: $row->{schedule_day}
		Time: $row->{schedule_time}
		Duration: $row->{schedule_duration}
ENDSHOWING
			;
			if( defined( $row->{part_id} ) )
			{
			    print DATA "\t\tPartIndex: $row->{part_id}\n";
			}
			if( defined( $row->{part_max} ) )
			{
			    print DATA "\t\tPartCount: $row->{part_max}\n";
			}
			if( $TiVoBits )
			{
			    print DATA "\t\tBits: $TiVoBits\n";
			}
			my $TvRating = FindTvRating( $row->{tvrating_id} );
			if( defined( $TvRating ) )
			{
			    print DATA "\t\tTvRating: $TvRating\n";
			}
			if( GetDontIndex($row->{program_tmsid}) )
			{
			    print DATA "\t\tDontIndex: 1\n";
			}
			print DATA "\t}\n";
			$iIdx++;
		    }
		    print DATA "}\n\n";
		}
	    }
	}
    }
    close DATA;
    rename("$ListingsTextfileDir/$HeadendId-$CurrentDay.txt", "$ListingsTextfileDir/$HeadendId"."_$CurrentDay-$EndDay.txt");

    debugprint(0, sprintf("$HeadendId %d sec\n", time() - $Start) );
    
}
################################
################################
################################

$Start = time();

open ALL, "> $ListingsTextfileDir/ALL-PROGRAMS_$CurrentDay-$AllEndDay.txt";
print ALL "Guide type=3\n\n";

if( $GenericSQL{SERIES}->{SELECT}->execute( $CurrentDay, $ValidTime ) )
{
    my $row;
    while( $row = $GenericSQL{SERIES}->{SELECT}->fetchrow_hashref() )
    {
        my $TiVoId = $row->{series_tivoid};
       	print ALL "Series/1/$TiVoId/$row->{series_ver} {\n";
       	print ALL "\tTmsId: {$row->{series_id}}\n" if ($row->{series_id} ne "");
       	print ALL "\tTitle: {$row->{series_title}}\n";
	if( $row->{series_id} =~ /^MV/ )
    	{
        	print ALL "\tEpisodic: 0\n";
    	} else {
		print ALL "\tEpisodic: 1\n";
	}
	print ALL PrintGenres( $row->{series_title}, undef, $row->{series_id} );
        print ALL <<ENDSERIES
}

ENDSERIES
;
    }
}
if( $GenericSQL{PROGRAMS}->{SELECT}->execute( $CurrentDay, $ValidTime ) )
{
    my $row;
    while( $row = $GenericSQL{PROGRAMS}->{SELECT}->fetchrow_hashref() )
    {
        my $TiVoProgramId = $row->{program_tivoid};
        my $TiVoSeriesId = $row->{series_tivoid};
	my $ProgramTmsId = $row->{program_tmsid};
	my $SeriesId = $row->{series_id};
	my $SeriesTitle = $row->{series_title};
        my $ProgramType = substr( $ProgramTmsId, 0, 2);
        print ALL <<ENDPROGRAM
Program/1/$TiVoProgramId/$row->{program_ver} {
	TmsId: {$row->{program_tmsid}}
	Title: {$row->{program_title}}
	Description: {$row->{program_description}}
ENDPROGRAM
;
        if( defined($row->{syndicated_episode_number}) )
	{
            my $EpisodeNum = $row->{syndicated_episode_number};
            
	    if( is_numeric($EpisodeNum) )
	    {
	        printf ALL "\tEpisodeNum: %d\n", $EpisodeNum;
	    }
	    else
	    {
	        print ALL "\tEpisodeNum: 0\n";
	    }
	}
        if( defined( $row->{original_air_date} ) )
	{
	    printf ALL "\tOriginalAirDate: %d\n", $row->{original_air_date};
	}
        if( defined( $row->{showtype_id} ) )
	{
	    printf ALL "\tShowType: %d\n", HandleShowType( $row->{showtype_id} );
	}
        if( defined( $row->{program_subtitle} ) )
        {
            print ALL "\tEpisodeTitle: {$row->{program_subtitle}}\n";
        }
        if( $ProgramType eq 'EP' )
        {
            print ALL "\tSeries: Series/1/$TiVoSeriesId\n";
            print ALL "\tIsEpisode: 1\n";
        } elsif ( ( $ProgramType eq 'SH' ) || ( $ProgramType eq 'SP' ) ) {
            print ALL "\tSeries: Series/1/$TiVoSeriesId\n";
            print ALL "\tIsEpisode: 0\n";
        } elsif ( $ProgramType eq 'MV' ) {
	    print ALL HandleMovieExtras( $ProgramTmsId );
            print ALL "\tSeries: Series/1/$TiVoSeriesId\n";
            print ALL "\tIsEpisode: 1\n";
	} else {
            print ALL "\tIsEpisode: 0\n";
	}
	
        $GenericSQL{CREW}->{SELECT}->execute( $ProgramTmsId );
        while( $row = $GenericSQL{CREW}->{SELECT}->fetchrow_hashref() )
        {
            my $Role = $row->{castrole};
            $Role =~ s/Guest Star/GuestStar/;
            $Role =~ s/Executive Producer/ExecProducer/;

            print ALL "\t$Role: {$row->{surname}|$row->{givenname}}\n";
        }
	print ALL PrintGenres( $SeriesTitle, $ProgramTmsId, $SeriesId );

	$GenericSQL{ADVISORY}->{SELECT}->execute( $ProgramTmsId );
        while( $row = $GenericSQL{ADVISORY}->{SELECT}->fetchrow_hashref() )
        {
            if( defined( $row->{tivoadvisory} ) )
            {
                print ALL "\tAdvisory: $row->{tivoadvisory}\n";
            } else {
                #print STDERR "Unknown tivogenre $row->{advisory}\n";
            }
        }
	
        print ALL <<ENDPROGRAM;
}

ENDPROGRAM
;
    }
}
close ALL;

debugprint(0, sprintf("ALLPrograms %d sec\n", time() - $Start));


$GenericSQL{SCHEDULE}->{DELETE}->execute( $CurrentDay - 1 );
$GenericSQL{STATIONDAYVER}->{DELETE}->execute( $CurrentDay - 1 );

sub debugprint()
{
    my $Debuglvl = shift;
    my $String   = shift;
    if( $Verbose > $Debuglvl )
    {
        print $String;
    }
}
