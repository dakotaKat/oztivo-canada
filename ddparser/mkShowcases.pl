#!/usr/bin/perl
#
#  $Id: mkShowcases.pl,v 1.4 2004/09/10 23:59:18 dboardman Exp $
#

print "****************************************\n";
print "* Starting mkShowcases.pl\n";
print "****************************************\n";

use strict;

# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use DBI;
use DDParserUtils;
use File::stat;
use FileHandle;
use POSIX qw(strtod);

# Switch to this program's directory
chdir($Bin);

use constant IMAGE_FORMAT_PNG => 2;

my $HEADEND_DIR = "$Bin/headend";

our $Database = DDParserUtils::cfg_val("database","name","tvdata");
our $dBUser = DDParserUtils::cfg_val("database","user","dbuser");
our $dBPassword = DDParserUtils::cfg_val("database","password","dbpassword");
my $dbtype = DDParserUtils::cfg_val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my $CurrentTime = time();
my $CurrentDay = $CurrentTime / 86400;
$CurrentDay =~ s/\..*$//;
$CurrentTime -= $CurrentDay * 86400;
my %GenericSQL;

$GenericSQL{SHOWCASES}->{SELECT} = $connection->prepare("SELECT * FROM Showcases" );
$GenericSQL{PACKAGES}->{SELECT} = $connection->prepare("SELECT * FROM Packages WHERE dsname=?" );
$GenericSQL{PACKAGEITEMS}->{SELECT} = $connection->prepare("SELECT DISTINCT * FROM PackageItems,Programs WHERE package_id=? AND PackageItems.program_tmsid=Programs.program_tmsid ORDER BY program_title" );
$GenericSQL{PACKAGEITEMS}->{DELETE} = $connection->prepare("DELETE FROM PackageItems WHERE expiration_day <= ?");
$GenericSQL{IMAGES}->{SELECT} = $connection->prepare("SELECT * FROM Images where image_id=?" );
$GenericSQL{ALLPROGRAMS}->{SELECT} = $connection->prepare("SELECT DISTINCT * FROM Series, Programs, PackageItems, Packages WHERE ((Series.series_id!='' AND Series.series_id=Programs.series_id) OR ((Series.series_id='' OR Programs.series_id='') AND Series.series_title=Programs.program_title)) AND Programs.program_tmsid=PackageItems.program_tmsid AND PackageItems.package_id=Packages.package_id AND Packages.dsname=?");
$GenericSQL{PROGRAMS}->{SELECT} = $connection->prepare("SELECT DISTINCT * FROM Series, Programs WHERE ((Series.series_id!='' AND Series.series_id=Programs.series_id) OR ((Series.series_id='' OR Programs.series_id='') AND Series.series_title=Programs.program_title)) AND Programs.program_tmsid=?");
$GenericSQL{PROGRAMS}->{SELECT_LBOX} = $connection->prepare("SELECT DISTINCT * FROM Programs,Schedule WHERE Programs.program_tmsid=Schedule.program_tmsid AND letterbox=1");
$GenericSQL{CREW}->{SELECT} = $connection->prepare("SELECT * FROM ProgramCast, Crew, CastRoles WHERE ProgramCast.castrole_id=CastRoles.castrole_id AND ProgramCast.crew_id = Crew.crew_id AND ProgramCast.program_tmsid=?");
$GenericSQL{ADVISORY}->{SELECT} = $connection->prepare("SELECT * FROM ProgramAdvisories, Advisories WHERE ProgramAdvisories.advisory_id = Advisories.advisory_id AND ProgramAdvisories.program_tmsid=?");
$GenericSQL{GENRE}->{SELECT} = $connection->prepare("SELECT * FROM ProgramGenre, Genres WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{GENRE}->{SELECT2} = $connection->prepare("SELECT tivogenre,genre FROM ProgramGenre, Genres, Programs WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid = Programs.program_tmsid AND Programs.series_id=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{GENRE}->{SELECT3} = $connection->prepare("SELECT tivogenre,genre FROM ProgramGenre, Genres, Programs WHERE ProgramGenre.genre_id = Genres.genre_id AND ProgramGenre.program_tmsid = Programs.program_tmsid AND Programs.program_title=? GROUP BY tivogenre ORDER BY relevance, tivogenre");
$GenericSQL{MOVIEINFO}->{SELECT} = $connection->prepare("SELECT * FROM MovieInfo WHERE program_tmsid=?");
$GenericSQL{MPAA}->{SELECT} = $connection->prepare("SELECT * FROM MpaaRatings WHERE mpaarating_id=?");
$GenericSQL{STAR}->{SELECT} = $connection->prepare("SELECT * FROM StarRatings WHERE starrating_id=?");

sub getnum
{
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
    if( $ProgramTmsId =~ /^MV/ )
    {
        $RetVal .= "\tGenre: 1006\n";
    }

    return $RetVal;
}

sub HandleShowType( $ )
{
    my $Id = shift;
    return $Id;
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

sub getTiVoImageID($)
{
    my $image_id = shift;
    return $image_id + 14350000;
}

sub printImage($$$)
{
    my ($fh,$dsname,$image_id) = @_;
    my $format = IMAGE_FORMAT_PNG;
    my $imageTiVoId = getTiVoImageID($image_id);
    my $row;
    if( $GenericSQL{IMAGES}->{SELECT}->execute($image_id) &&
        ($row = $GenericSQL{IMAGES}->{SELECT}->fetchrow_hashref()) )
    {
        my $image_name = $row->{name};
        my $stat = stat("$HEADEND_DIR/$image_name");
        if (!defined($stat) || $stat->size == 0)
        {
            print STDERR "mkShowcases.pl failure, missing image $HEADEND_DIR/$image_name\n";
            exit(1);
        }
        my $size = $stat->size;
        print $fh <<EOF1
Image/1/$imageTiVoId/$row->{image_ver} {
	Name: {$image_name}
	File: File of size 1/$size
	Format: $format
}

EOF1
;
    }
}

sub printSeries($)
{
    my ($fh) = @_;
    if( $GenericSQL{SERIES}->{SELECT}->execute() )
    {
        my $row;
        while( $row = $GenericSQL{SERIES}->{SELECT}->fetchrow_hashref() )
        {
            my $TiVoId = $row->{series_tivoid};
            print $fh "Series/1/$TiVoId/$row->{series_ver} {\n";
            print $fh "\tTmsId: {$row->{series_id}}\n" if ($row->{series_id} ne "");
            print $fh "\tTitle: {$row->{series_title}}\n";
            if( $row->{series_id} =~ /^MV/ )
            {
                print $fh "\tEpisodic: 0\n";
            } else {
                print $fh "\tEpisodic: 1\n";
            }
            print $fh PrintGenres( $row->{series_title}, undef, $row->{series_id} );
            print $fh "}\n\n";
        }
    }
}

sub printProgram($$)
{
    my ($fh,$progid) = @_;
    if( $GenericSQL{PROGRAMS}->{SELECT}->execute( $progid ) )
    {
        my $row;
        while( $row = $GenericSQL{PROGRAMS}->{SELECT}->fetchrow_hashref() )
        {
            print $fh "Series/1/$row->{series_tivoid}/$row->{series_ver} {\n";
            print $fh "\tTmsId: {$row->{series_id}}\n" if ($row->{series_id} ne "");
            print $fh "\tTitle: {$row->{series_title}}\n";
            if( $row->{series_id} =~ /^MV/ )
            {
                print $fh "\tEpisodic: 0\n";
            } else {
                print $fh "\tEpisodic: 1\n";
            }
            print $fh PrintGenres( $row->{series_title}, undef, $row->{series_id} );
            print $fh "}\n\n";

            my $TiVoProgramId = $row->{program_tivoid};
            my $TiVoSeriesId = $row->{series_tivoid};
            my $ProgramTmsId = $row->{program_tmsid};
            my $SeriesId = $row->{series_id};
            my $SeriesTitle = $row->{series_title};
            my $ProgramType = substr( $ProgramTmsId, 0, 2);
            print $fh <<ENDPROGRAM
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
                    printf $fh "\tEpisodeNum: %d\n", $EpisodeNum;
                }
                else
                {
                    print $fh "\tEpisodeNum: 0\n";
                }
            }
            if( defined( $row->{original_air_date} ) )
            {
                printf $fh "\tOriginalAirDate: %d\n", $row->{original_air_date};
            }
            if( defined( $row->{showtype_id} ) )
            {
                printf $fh "\tShowType: %d\n", HandleShowType( $row->{showtype_id} );
            }
            if( defined( $row->{program_subtitle} ) )
            {
                print $fh "\tEpisodeTitle: {$row->{program_subtitle}}\n";
            }
            if( $ProgramType eq 'EP' )
            {
                print $fh "\tSeries: Series/1/$TiVoSeriesId\n";
                print $fh "\tIsEpisode: 1\n";
            } elsif ( ( $ProgramType eq 'SH' ) || ( $ProgramType eq 'SP' ) ) {
                print $fh "\tSeries: Series/1/$TiVoSeriesId\n";
                print $fh "\tIsEpisode: 0\n";
            } elsif ( $ProgramType eq 'MV' ) {
                print $fh HandleMovieExtras( $ProgramTmsId );
                print $fh "\tSeries: Series/1/$TiVoSeriesId\n";
                print $fh "\tIsEpisode: 1\n";
            } else {
                print $fh "\tIsEpisode: 0\n";
            }

            $GenericSQL{CREW}->{SELECT}->execute( $ProgramTmsId );
            while( $row = $GenericSQL{CREW}->{SELECT}->fetchrow_hashref() )
            {
                my $Role = $row->{castrole};
                $Role =~ s/Guest Star/GuestStar/;
                $Role =~ s/Executive Producer/ExecProducer/;

                print $fh "\t$Role: {$row->{surname}|$row->{givenname}}\n";
            }
            print $fh PrintGenres( $SeriesTitle, $ProgramTmsId, $SeriesId );

            $GenericSQL{ADVISORY}->{SELECT}->execute( $ProgramTmsId );
            while( $row = $GenericSQL{ADVISORY}->{SELECT}->fetchrow_hashref() )
            {
                if( defined( $row->{tivoadvisory} ) )
                {
                    print $fh "\tAdvisory: $row->{tivoadvisory}\n";
                } else {
                    #print STDERR "Unknown tivogenre $row->{advisory}\n";
                }
            }

            print $fh "}\n\n";
        }
    }
}

$GenericSQL{PACKAGEITEMS}->{DELETE}->execute( $CurrentDay - 1 );

my $dsExpirationDay = $CurrentDay;
if( $GenericSQL{SHOWCASES}->{SELECT}->execute() )
{
    my $row;
    while( $row = $GenericSQL{SHOWCASES}->{SELECT}->fetchrow_hashref() )
    {
        my $scExpirationDay = $CurrentDay;
        my $scExpirationTime = 0;
        my $dsName = $row->{dsname};
        my $TiVoId = $row->{showcase_id} + 9200000;
        my $eDate = $row->{expiration_day};
        my $rDate = $row->{expiration_day}-10;
        my $filename = $dsName;
        my $fh = new FileHandle;
        open ($fh, "> $HEADEND_DIR/$filename");
        print $fh "Guide type=3\n\n";
        my %imageIDs;
        $imageIDs{$row->{banner_image_id}} = 1;
        $imageIDs{$row->{bigbanner_image_id}} = 1;
        $imageIDs{$row->{icon_image_id}} = 1;
        if( $GenericSQL{PACKAGES}->{SELECT}->execute($dsName) )
        {
            my $row2;
            while( $row2 = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref() )
            {
                $imageIDs{$row2->{banner_image_id}} = 1;
            }
        }
        foreach my $uniqueImageID (keys %imageIDs)
        {
            printImage($fh,$dsName,$uniqueImageID);
        }

        if( $GenericSQL{ALLPROGRAMS}->{SELECT}->execute($dsName) )
        {
            my $row2;
            while( $row2 = $GenericSQL{ALLPROGRAMS}->{SELECT}->fetchrow_hashref() )
            {
                printProgram($fh,$row2->{program_tmsid});
            }
        }

        if( $GenericSQL{PACKAGES}->{SELECT}->execute($dsName) )
        {
            my $row2;
            while( $row2 = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref() )
            {
                my $bannerID = getTiVoImageID($row2->{banner_image_id});
                my $package_tivoid = $row2->{package_id} + 7070000;
                print $fh <<ENDSHOWCASE
Package/1/$package_tivoid/$row2->{package_ver} {
	Banner: Image/1/$bannerID
	InfoBalloon: $row2->{infoballoon}
ENDSHOWCASE
;
                if( $GenericSQL{PACKAGEITEMS}->{SELECT}->execute($row2->{package_id}) )
                {
                    my $iIdx = 11;
                    my $row3;
                    while( $row3 = $GenericSQL{PACKAGEITEMS}->{SELECT}->fetchrow_hashref() )
                    {
                        print $fh "\tItem: PackageItem/$iIdx\n";
                        ++$iIdx;
                    }
                }
                my $packageUniqueID = $row2->{dsname}."|".$row2->{name};
		$packageUniqueID =~ s/ /%20/g;
                print $fh <<ENDSHOWCASE
	Name: {$row2->{name}}
	UniqueId: {$packageUniqueID}
ENDSHOWCASE
;
                if( $GenericSQL{PACKAGEITEMS}->{SELECT}->execute($row2->{package_id}) )
                {
                    my $iIdx = 11;
                    my $row3;
                    while( $row3 = $GenericSQL{PACKAGEITEMS}->{SELECT}->fetchrow_hashref() )
                    {
                        if (($row3->{expiration_day} > $scExpirationDay)
                             || ($row3->{expiration_day} eq $scExpirationDay) && ($row3->{expiration_time} > $scExpirationTime))
                        {
                            $scExpirationDay = $row3->{expiration_day};
                            $scExpirationTime = $row3->{expiration_time};
                        }
			my $packageItemName = $row3->{program_title};
			$packageItemName .= " \"" . $row3->{program_subtitle} ."\"" if defined($row3->{program_subtitle});
			my $packageItemDescription = $row3->{description};
                        print $fh <<ENDSHOWCASE
	Subrecord PackageItem/$iIdx {
		Name: {$packageItemName}
		Description: {$packageItemDescription}
		ExpirationDate: $row3->{expiration_day}
		ExpirationTime: $row3->{expiration_time}
		Program: Program/1/$row3->{program_tivoid}
	}
ENDSHOWCASE
;
                        ++$iIdx;
                    }
                }
                print $fh "}\n\n";
            }
        }

        my $bannerID = getTiVoImageID($row->{banner_image_id});
        my $bigBannerID = getTiVoImageID($row->{bigbanner_image_id});
        my $iconID = getTiVoImageID($row->{icon_image_id});
        print $fh <<ENDSHOWCASE
Showcase/1/$TiVoId/$row->{showcase_ver} {
	Banner: Image/1/$bannerID
	BigBanner: Image/1/$bigBannerID
	DataSetName: {$dsName}
	ExpirationDate: $scExpirationDay
	ExpirationTime: $scExpirationTime
	Icon: Image/1/$iconID
ENDSHOWCASE
;

        if ($scExpirationDay > $dsExpirationDay)
        {
            $dsExpirationDay = $scExpirationDay;
        }
        if( $GenericSQL{PACKAGES}->{SELECT}->execute($dsName) )
        {
            my $iIdx = 11;
            my $row2;
            while( $row2 = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref() )
            {
                print $fh "\tItem: ShowcaseItem/$iIdx\n";
                ++$iIdx;
            }
        }
        print $fh <<ENDSHOWCASE
	Name: {$row->{name}}
	SequenceNumber: $row->{seq_num}
ENDSHOWCASE
;
        if( $GenericSQL{PACKAGES}->{SELECT}->execute($dsName) )
        {
            my $iIdx = 11;
            my $row2;
            while( $row2 = $GenericSQL{PACKAGES}->{SELECT}->fetchrow_hashref() )
            {
                my $package_tivoid = $row2->{package_id} + 7070000;
                print $fh <<ENDSHOWCASE
	Subrecord ShowcaseItem/$iIdx {
		Description: {$row2->{description}}
		ExpirationDate: $scExpirationDay
		ExpirationTime: $scExpirationTime
		Name: {$row2->{name}}
		Package: Package/1/$package_tivoid
	}
ENDSHOWCASE
;
                ++$iIdx;
            }
        }
        print $fh "}\n\n";

        print $fh <<ENDSHOWCASE
DataSet/1/14359529/$row->{showcase_ver} {
	Data: Showcase/1/$TiVoId
	Date: $dsExpirationDay
	ExpirationPolicy: 1
	GcZapPolicy: 3
	Name: {$dsName}
}

ENDSHOWCASE
;
        close($fh);
	my $eDate = $dsExpirationDay;
	my $rDate = $eDate-10;
        my $filename = $dsName;
        $filename =~ s/_/-/g;
        $filename .= "-e".$eDate."-r".$rDate."-v".$row->{showcase_ver}.".txt";
        rename("$HEADEND_DIR/$dsName", "$HEADEND_DIR/$filename");
    }
}
