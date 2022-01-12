#!/usr/bin/perl
#
# parsexmlguide.pl by Xnaron 2002 DEC 21
#
# This is a replacement for parsepages in the tivo guide scripts.
# 
# Installation
# 1. install xmltv http://membled.com/work/apps/xmltv/
# 2. run tv_grab_na --configure (part of xmltv) and setup your lineup
# 3. put this file in the same directory as parsepages
# 4. run tv_grab_na --days 10 >listings.xml (this creates the xml file 
#    listings.xml with the guide data for your lineup for 10 days)
# 5. Make sure you configure everything below in USER CONFIGURATION
# 6. run ./parsexmlguide.pl
# 7. look in the shows directory and retrieve the lowest number (there 
#    will be 11)
# 8. run ./makeslice "numberFromStep7+10" > yourslicefile.slice
# 9. move the slice file to your tivo and load it
#
#
# Adjust your tivo automation scripts accordingly to accomodate above.
#
########################################################################

use XML::Parser;
use Date::Manip;
use Time::Local;
use lib ".";
use TiVo::ServerId::Series;
use TiVo::Show;
use Getopt::Long;
use POSIX;

my $parser = new XML::Parser;
my $quiet;
my $listings;
GetOptions('quiet' => \$quiet, 'file=s' => \$listings);

########################################################################
# USER CONFIGURATION BEGIN 
#
# path to where your shows directory lives. No trailing slash
my $pathToShows="./shows";
# The locaion and name of your stations.txt file
my $stationsFile="./stations.txt";
# The location and name of your myprogid file. Will be created for you 
my $myProgFile="./myprogidfile";
my $myLastProgFile="./myLastprogs";
#
# USER CONFIGURATION END
########################################################################


# start first programID at this number if myprogid doesn't exist
my $progIDStart=110000000;

use strict;
use GDBM_File;
use vars qw( %ProgTable %LastProgs);

tie (%ProgTable, "GDBM_File", $myProgFile, &GDBM_WRCREAT, 0644);
# start first seriesID at this number if myseriesfile doesn't exist
tie (%LastProgs, "GDBM_File", $myLastProgFile, &GDBM_WRCREAT, 0644);


my %genres = (
	"action" => [1011,1],
	"ad" => [1011,1],
	"adult" => [1005,2],
	"adults only" => [1000,2],
	"adventure" => [1011,1],
	"aerobics" => [1009,48],
	"agriculture" => undef,
	"animals" => [1008,3],
	"animated" => [1002,4],
	"anime" => [1002,4],
	"anthology" => [1000,5],
	"archery" => [1009,101],
	"arm wrestling" => [1009,101],
	"art" => [1000,6],
	"arts/crafts" => [1000,6],
	"auction" => [1010,44],
	"auto" => [1000,7],
	"auto racing" => [1009,7,120],
	"aviation" => [1008,87],
	"awards" => [1000,9],
	"awards show" => [1000,9],
	"badminton" => [1009,101],
	"ballet" => [1000,10],
	"baseball" => [1009,11],
	"basketball" => [1009,12],
	"beach soccer" => [1009,101],
	"beach volleyball" => [1009,101],
	"beauty" => [13],
	"biathlon" => [1009,101],
	"bicycle" => [1009,14],
	"bicycle racing" => [1009,14],
	"billiards" => [1009,15],
	"bio" => [1004,16],
	"biography" => [1004,16],
	"biz" => [1007,21],
	"boat" => [1010,17],
	"boat racing" => [1009,17],
	"bobsled" => [1009,101],
	"bodybuilding" => [1009,18],
	"bowling" => [1009,19],
	"boxing" => [1009,20],
	"bullfighting" => [1009,101],
	"bus./financial" => [1007,21],
	"business" => [1007,21],
	"canoe" => undef,
	"cheerleading" => [1009,101],
	"children" => [1001,22],
	"children-music" => [1001,69],
	"children's" => [1001,22],
	"children-special" => [1001,100],
	"children-talk" => [1001,106],
	"classic" => [23],
	"collectibles" => [1000,24],
	"comedy" => [1002,25],
	"comedy-drama" => [1002,1005,25,35],
	"community" => undef,
	"computers" => [1008,26],
	"consumer" => undef,
	"cooking" => [1000,27],
	"courtroom" => [28],
	"cricket" => [1009,101],
	"crime" => [1005,29],
	"crime drama" => [1005,30],
	"curling" => [1009,31],
	"dance" => [1000,32],
	"darts" => [1009,101],
	"debate" => [1010,106],
	"diving" => [1009,101],
	"doc" => [1004,34],
	"docudrama" => [1005,33],
	"documentary" => [1004,34],
	"dog racing" => [1009,101],
	"dog show" => [1000,9],
	"dog sled" => [1009,101],
	"drag racing" => [1009,101],
	"drama" => [1005,35],
	"edu" => [1012,36],
	"educational" => [1012,36],
	"electronics" => [1008,37],
	"entertainment" => [1000,106],
	"entertainment news" => undef,
	"environment" => [1008,72],
	"equestrian" => [1009,101],
	"event" => undef,
	"exercise" => [1009,48],
	"extreme" => [1009,101],
	"fantasy" => [1014,39],
	"fashion" => [1000,40],
	"fencing" => [1009,101],
	"field hockey" => [1009,101],
	"figure skating" => [1009,101],
	"fin" => [1007,21],
	"financial" => [21],
	"fishing" => [1009,41],
	"fitness" => [1000,48,13],
	"football" => [1009,42],
	"french" => [1000,43],
	"fundraiser" => [1000,44],
	"gaelic football" => [1009,101],
	"game" => [1012,45],
	"game show" => [1003,45],
	"gay/lesbian" => undef,
	"golf" => [1009,46],
	"gymnastics" => [1009,47],
	"handball" => [1009,101],
	"health" => [1000,48],
	"historical" => [1004,49],
	"historical drama" => [1005,50],
	"history" => [1012,49],
	"hockey" => [1009,51],
	"holiday" => [52],
	"holiday music" => [1000,52,69],
	"holiday music special" => [1000,52,69,100],
	"holiday special" => [53],
	"holiday-children" => [1001,52],
	"holiday-children special" => [1001,53],
	"home and garden" => [54],
	"home improvement" => [1000,54],
	"horror" => [1013,55],
	"horse" => [1009,56],
	"house/garden" => [1000,54],
	"housewares" => [57],
	"how-to" => [1004,58],
	"hunting" => [1009,101],
	"hurling" => [1009,101],
	"hydroplane racing" => [1009,101],
	"indoor soccer" => [1009,101],
	"info" => [1004,34],
	"interview" => [1010,60],
	"intl basketball" => [1009,59,12],
	"intl hockey" => [1009,59,51],
	"intl soccer" => [1009,59,97],
	"jewelry" => [61],
	"kayaking" => [1009,101],
	"lacrosse" => [1009,62],
	"law" => [1007,35],
	"luge" => [1009,101],
	"magazine" => [1000,63],
	"martial arts" => [1009,64],
	"medical" => [1008,65],
	"motorcycle" => [1009,67],
	"motorcycle racing" => [1009,67,120],
	"motorsports" => [1009,66],
	"mountain biking" => [1009,14],
	"movie" => [68],
	"music" => [1000,69],
	"music special" => [1000,69,100],
	"music talk" => [1000,69,106],
	"musical" => [1000,69,70],
	"musical comedy" => [1002,70],
	"mystery" => [1013,71],
	"nature" => [1008,72],
	"news" => [1007,73],
	"olympics" => [1009,74],
	"opera" => [1000,75],
	"outdoors" => [1008,76],
	"parade" => undef,
	"paranormal" => [1014,71],
	"parenting" => [1000,38],
	"performing arts" => [1000,32],
	"politics" => [1007,77],
	"polo" => [1009,101],
	"pool" => [1009,101],
	"pro wrestling" => [1009,101],
	"public affairs" => [1007,77],
	"racquet" => [1009,101],
	"reality" => [1015,79],
	"religion" => [80],
	"religious" => [1003,80],
	"rodeo" => [1009,81],
	"roller derby" => [1009,101],
	"romance" => [1005,82],
	"romance-comedy" => [1002,83],
	"rowing" => [1009,101],
	"rugby" => [1009,84],
	"running" => [1009,85],
	"sailing" => [1009,17],
	"science" => [1008,87],
	"science fiction" => [1014,88],
	"scifi" => [1014,88],
	"self improvement" => [1000,89],
	"series" => undef,
	"shopping" => [1010,90],
	"sitcom" => [1002,25],
	"situation" => [1002,91],
	"skateboarding" => [1009,101],
	"skating" => [1009,92],
	"skiing" => [1009,93],
	"snooking" => [1009,101],
	"snowboarding" => [1009,95],
	"snowmobile" => [1009,95],
	"soap" => [1003,96],
	"soap opera" => [1005,35,96],
	"soap special" => [1003,100,96],
	"soap talk" => [1003,106,96],
	"soaps" => [1003,96],
	"soccer" => [1009,97],
	"softball" => [1009,98],
	"spanish" => [99],
	"special" => [100],
	"speed racing" => [1009,101],
	"spiritual" => [1000,80],
	"sport - events" => [1009,101],
	"sports" => [1009,101],
	"sports event" => [1009,101],
	"sports info" => [1009,102],
	"sports	news" => [1009,102],
	"sports talk" => [1009,106],
	"squash" => [1009,101],
	"standup" => [1002,25],
	"sumo wrestling" => [1009,101],
	"surfing" => [1009,101],
	"suspense" => [1013,104],
	"swimming" => [1009,105],
	"talk show" => [1000,107,106],
	"tabloid" => [1010,106],
	"talk" => [1010,106],
	"tennis" => [1009,108],
	"theatre" => [1000,109],
	"thriller" => [110],
	"track/field" => [1009,111],
	"travel" => [1000,112],
	"variety" => [1002,113],
	"volleyball" => [1009,114],
	"war" => [1005,115],
	"water polo" => [1009,116],
	"water skiing" => [1009,116],
	"watersports" => [1009,116],
	"weather" => [1007,117],
	"western" => [1015,118],
	"westerns" => [1015,118],
);

########################################################################
# MAIN - BEGIN
#
$parser->setHandlers( Start => \&StartElement,
		      End   => \&EndElement,
		      Char  => \&CharacterData,
		      Default => \&Default);

print "parsexmlguide: about to parse $listings\n" if not $quiet;
my $current_node = 0;
my $doc = $parser->parsefile ($listings);
print "\n" if not $quiet;
#
#  MAIN - END
########################################################################


########################################################################
#
# SUBROUTINES
#
sub getProgID() {
    my $show = shift;
    my $ProgID;
    my $Hashkey = '';
    my $LastProg = 110087737;
    my $Record;
    my %RecordHash;

    if( $show->title ) {
	$Hashkey .= $show->title;
    }
    if( $show->episodic || $show->is_episode || $show->episode ) {
	$Hashkey .= "|".$show->episode;
    }
    if( $show->description ) {
	$Hashkey .= "|".$show->description;
    }

    $Record = $ProgTable{$Hashkey};
    if( defined( $Record ) ) {
	%RecordHash = split( '\|', $Record );
    }

    if( defined($Record) ) {
	$ProgID=$RecordHash{progid};
    } else {
	$ProgID = $ProgTable{"LastID"} +1;
	if( $ProgID < 110000000 ) {
	    $ProgID = 110000000;
	}
	$ProgTable{"LastID"} = $ProgID;
	$ProgTable{$Hashkey} = 'progid|'.$ProgID.'|'.'time|'.time();
    }
    return $ProgID;
}

# Returns the GMT epoch day for a given date
# note: date is local time
#
sub dateToEpochDay {
    my($date)=@_;    
    my($year)=substr($date,0,4);
    my($month)=substr($date,4,2)-1;
    my($day)=substr($date,6,2);
    my($hour)=substr($date,8,2);
    my($minute)=substr($date,10,2);
    my($second)=substr($date,12,2);
    
    my $epochDayThen=((timelocal($second,$minute,$hour,$day,$month,$year))/86400);
    
    my @epochDay = split /\./, $epochDayThen; 
    
    return $epochDay[0]; #return only the day not the decimal
}

# Returns the shows start time from 0h GMT in seconds for a given date.
# note: timeStr is local time
#
sub epochTimeGMT {
    my ($timeStr)=@_;
    my($year)=substr($timeStr,0,4);
    my($month)=substr($timeStr,4,2)-1;
    my($day)=substr($timeStr,6,2);
    my($hour)=substr($timeStr,8,2);
    my($minute)=substr($timeStr,10,2);
    my($second)=substr($timeStr,12,2);
    
    my $secsStart=((timelocal($second,$minute,$hour,$day,$month,$year)));
    
    my $secsDay=((&dateToEpochDay($timeStr))*86400);
    
    &Date_Init();
    #returns the start time in seconds since 0000h gmt
    return ($secsStart-$secsDay); 
}

# Return the tivo serverid for a given channel
#
#
sub getStationFromChannel {	
    my($channel)=@_;
    my @channelArray=split / / , $channel;
    my $channelNum=@channelArray[0];
    my $found=0;
    my $stationName;
    my $stationTest;
    my $test_stations;
    my @lineArray;
    my $stationID;
    my $line;
    my $stationName;
    my $stationTest;
    my $test_stations;
    
    open (STATIONFILE,"<$stationsFile");
    
    while (!$found and $line=<STATIONFILE>){
        @lineArray=split /,/ , $line; 
        if($lineArray[1] =~ /^.+\.zap2it\.com$/i) {
            $stationTest = $lineArray[1];
            } else {
            $stationName = lc($lineArray[1]);
            $stationTest = "C$lineArray[0]$stationName.zap2it.com";
            }
        if ($stationTest eq $channelNum) {
            $found=1;
            $stationID=$lineArray[3];	
        }
    }
    close (STATIONFILE);
    $stationID=~s/^\s*(.*?)\s*$/$1/;
    return $stationID;
}

# Take a start time and stop time and return duration in seconds
#
#
sub getDuration {
    my ($start,$stop)=@_;
    my $startSec=&Date_SecsSince1970GMT(substr($start,4,2),
    					substr($start,6,2),
					substr($start,0,4),
					substr($start,8,2),
					substr($start,10,2),
					substr($start,12,2));
    my $stopSec;
    if( defined( $stop ) ) {
	$stopSec=&Date_SecsSince1970GMT(substr($stop,4,2),
					substr($stop,6,2),
					substr($stop,0,4),
					substr($stop,8,2),
					substr($stop,10,2),
					substr($stop,12,2));
    } else {
	$stopSec = $startSec + (2*60*60);
    }
    return ($stopSec-$startSec);
}

# Validates a rating conforms to TVRATING
# 
# 
sub checkTVRating {
    my $rating_raw = shift;
    $rating_raw =~ s/(TV-?)?(Y7|Y|G|PG|14|MA|M)-?((FV|[DLSV])*)//;
    my ($rating, $advisories) = ($2, $3);
    warn "leftover rating blobs: `$rating_raw'" if $rating_raw;
    return wantarray ? $rating : ($rating, $advisories);  
}


my $show = undef;
my @TagStack = ();
my @AttrStack = ();

sub StartElement() {
    print "now at node $current_node\r" if not $quiet;
    $current_node++;
    my( $parseinst, $element, %attrs ) = @_;
    unshift @TagStack, $element;
    unshift @AttrStack, \%attrs;
    if ($element eq "programme") {
        $show = TiVo::Show->new;
        undef $$show{"converter"};  #don't do any charset conversion
        if( defined($LastProgs{$attrs{channel}}) ) {
            my ($Day, $Time) = split("'",$LastProgs{$attrs{channel}});
            $show->day($Day);
            $show->station(&getStationFromChannel($attrs{channel}));
            $show->time($Time);
            $show->incomplete(1);
            if($show->load()) {
                $show->end($attrs{start});
                $show->duration(&getDuration($show->start(),$attrs{start}));
                $show->save();
                delete( $LastProgs{$attrs{channel}} );
            }
            $show = TiVo::Show->new;
            undef $$show{"converter"};  #don't do any charset conversion
        }
        $show->station(&getStationFromChannel($attrs{channel}));
        $show->day(&dateToEpochDay($attrs{start}));
        $show->start($attrs{start});
        $show->time(&epochTimeGMT($attrs{start}));
        if( defined( $attrs{stop} ) ) {
            $show->end($attrs{stop});
            $show->duration(&getDuration($attrs{start},$attrs{stop}));
        } else {
            $LastProgs{$attrs{channel}} = $show->day()."'".$show->time();
        }
        $show->is_episode(0);
    }
}

my $CurValue = '';
sub EndElement {
    my( $parseinst, $element ) = @_;
    if ($TagStack[0] ne $element) {
	print "Error\n";
    }
    if ($element eq "programme") {
	$show->program(&getProgID($show));
	if( $show->description =~ /animated/i ) { $show->genre(4); }
	if( $show->description =~ /^(.*)Directed by (.*?)\.(.*)/ ) {
	    my $Director = $2;
	    my $Descr = $1.$3;
	    $Director =~ s/^(.*) +(.*?)$/$2|$1/;
	    $show->director($Director);
	    $show->description($Descr);
	}
	$show->save();
    }
    elsif( $element eq "title" ) {
	my $id = TiVo::ServerId::Series->new("",$show->title,1);
	$show->series($id->value);
    }
    elsif ( $element eq "previously-shown" ) {
	$show->repeat(1);
	my $tmp = $show->tivobits();
	$tmp |= 0x200;
	$show->tivobits($tmp);
    }
    elsif( $element eq 'actor' or $element eq 'guest' ) {
	if( $CurValue =~ /^(.*?),\s*(.*)$/ ) {
	    $show->actor( "$1|$2" );
	}
	elsif( $CurValue =~ /^(.*?) (.*)$/ ) {
	    $show->actor( "$2|$1" );
	} else {
	    $show->actor($CurValue);
	}
    }
    elsif( $element eq 'director' ) {
	if( $CurValue =~ /^(.*?),\s*(.*)$/ ) {
	    $show->director( "$1|$2" );
	}
	elsif( $CurValue =~ /^(.*?) (.*)$/ ) {
	    $show->director( "$2|$1" );
	} else {
	    $show->director($CurValue);
        }
    }
    elsif( $element eq 'presenter' ) {
	if( $CurValue =~ /^(.*?),\s*(.*)$/ ) {
	    $show->presenter( "$1|$2" );
	}
	elsif( $CurValue =~ /^(.*) (.*?)$/ ) {
	    $show->presenter( "$2|$1" );
	} else {
	    $show->presenter($CurValue);
        }
    }
     elsif( $element eq 'commentator' ) {
        if( $CurValue =~ /^(.*?),\s*(.*)$/ ) {
            $show->host( "$1|$2" );
        }
        elsif( $CurValue =~ /^(.*) (.*?)$/ ) {
            $show->host( "$2|$1" );
        } else {
            $show->host($CurValue);
        }
    }
    elsif( $element eq 'premiere' ) {
	$show->premiere('Premiere');
    }
    elsif ( $element eq "subtitles" ) {
	my $Tmp = $show->tivobits();
	if ($AttrStack[0]->{type} eq "teletext") {
	    $show->cc(1);
	    $Tmp |= 1 << 0;  # 0x01
	    $show->tivobits( $Tmp );
	} elsif ($AttrStack[0]->{type} eq "onscreen") {
	    $show->open_subtitles( 1 );
	    $Tmp |= 1 << 2;  # 0x04
	    $show->tivobits($Tmp);
	}
    }
    shift @TagStack;
    shift @AttrStack;
    $CurValue = '';
}

sub CharacterData {
    my( $parseinst, $data ) = @_;
    if( $TagStack[0] eq "title" ) {
	my $oldTitle = $show->title;
	if( $oldTitle ne "" ) {
	    $oldTitle .= "$data";
	    $data = $oldTitle;
	}
	$show->title($data);
    }
    elsif ($TagStack[0] eq "sub-title") {
	my $EpTitle;
	$EpTitle = $show->episode;
	$EpTitle .= $data;
	$show->episode($EpTitle);
	$show->is_episode(1);
    }
    elsif( $TagStack[0] eq "episode-num" ) {
	    if ($AttrStack[0]->{system} eq "xmltv_ns") {
	my $EpTitle;
	$EpTitle = $show->episode;
	## fix the zap2it's wanky part x/x problem
	$data =~ /.*(\d+)\/(\d+)/;
	$data = $1 + 1 . "/$2";
	$show->episode((defined($EpTitle)?$EpTitle:"")." (".$data.")");
	}
    }
    elsif( $TagStack[0] eq "desc" ) {
	$show->description($show->description.$data);
    }
    elsif( $TagStack[0] eq "category") {
	my $genre;
	foreach $genre ( @{$genres{lc($data)}} )
	{
	    $show->genre($genre);
	}
    }
    elsif ($TagStack[0] eq "value") {
	if( $TagStack[1] eq "rating" ) {
	    if ($AttrStack[1]->{"system"} eq "VCHIP") {
		my $rating_raw = $data;
		my ($rating, $advisories) = checkTVRating(uc($data));
		$rating = "TV$rating";
		$rating .= "-$advisories" if $advisories;
		$show->tvrating($rating);
		# handle advisories by setting the appropriate tivobits
		my $tivobits = $show->tivobits;
		if ($advisories =~ s/FV//) { $tivobits |= 1 << 20; }
		if ($advisories =~ s/D//)  { $tivobits |= 1 << 19; }
		if ($advisories =~ s/L//)  { $tivobits |= 1 << 18; }
		if ($advisories =~ s/S//)  { $tivobits |= 1 << 16; }
		if ($advisories =~ s/V//)  { $tivobits |= 1 << 17; }
		warn "unknown content advisories $advisories" if $advisories ne '';
		$show->tivobits($tivobits);
	    }
	    elsif ($AttrStack[1]->{"system"} eq "MPAA") {
		$show->mpaarating($data);
		$show->movie(1);
		$show->genre(1006);
		$show->episodic(0);
	    }
	    elsif ($AttrStack[1]->{"system"} eq "ESRB") {
		# do nothing for now
	    }
	    elsif ($AttrStack[1]->{"system"} eq "advisory") {
		    # do nothing for now
            }
	    else {
		warn "unimplemented rating system '$AttrStack[1]->{system}'";
	    }
	}
	elsif( $TagStack[1] eq "star-rating" ) {
	    my $Stars;
	    $data =~ /^(\d+)(\.(\d+))?\s*\/\s*(\d+)/;
	    my ( $Whole, $Fract, $Divisor ) = ($1, $3, $4);
            # convert to /4
            if ($Divisor != 4 and $Divisor != 0)
            {
                my ($Num) = $Whole + $Fract/10;
                $Num = 4 * $Num / $Divisor;
                # round to nearest half in a tricky way
                $Num = POSIX::floor(2*$Num + 0.5) / 2;
                $Whole = POSIX::floor($Num);
                $Fract = ($Num - $Whole) * 10;
            }
	    $Stars = "*"x$Whole;
	    $Stars .= '+' if $Fract;
	    $show->starrating($Stars);
	    $show->movie(1);
	    $show->genre(1006);
	    $show->episodic(0);
	}
    } 
    elsif( $TagStack[0] eq "date" ) {
	    if ( $data =~ m/^[0-9]{4}$/ ) {
	$show->year($data);
	$show->movie(1);
	$show->genre(1006);
	$show->episodic(0);
	}
    }
    elsif ( $TagStack[0] eq "stereo" ) {
	my $Tmp = $show->tivobits();
	$show->stereo(1);
	$Tmp |= 0x02;
	$show->tivobits( $Tmp );
    }
    elsif( $TagStack[0] eq 'actor' or $TagStack[0] eq 'guest' ) {
	$CurValue .= $data;
    }
    elsif( $TagStack[0] eq 'director' ) {
	$CurValue .= $data;
    }
    elsif( $TagStack[0] eq 'commentator' ) {
        $CurValue .= $data;
    }
    elsif( $TagStack[0] eq 'presenter' ) {
	$CurValue .= $data;
    }
    elsif( $TagStack[0] eq 'language' ) {
	$show->language($data);
    }
    elsif ($TagStack[0] eq "video") {
	my $colourType = $AttrStack[0]->{"colour"};
	# assume colour unless it explicitly says black and white
	if (defined $colourType and $colourType eq "no") {
	    $show->colour(4);
	}
	else {
	    $show->colour(1);
	}
	my $aspectRatio = $AttrStack[0]->{"aspect"};
	$aspectRatio =~ /([0-9]+):([0-9]+)/;
	if (defined $aspectRatio and $1/$2 > 4/3) {
	    $show->widescreen(1);
	    # Assume letterbox if picture is wider than 4:3.
	    $show->tivobits($show->tivobits | 1<<10);
	}
    }
    elsif (   $TagStack[0] eq "tv"
	   or $TagStack[0] eq "channel"
	   or $TagStack[0] eq "display-name"
	   #or $TagStack[0] eq "language"
	   or $TagStack[0] eq "url"
	   # these are only used as containers for other elements
	   or $TagStack[0] eq "programme"
	   or $TagStack[0] eq "rating"
	   or $TagStack[0] eq "audio"
	   or $TagStack[0] eq "channel"
	   or $TagStack[0] eq "star-rating"
	   or $TagStack[0] eq "credits"
           or $TagStack[0] eq "writer"
           or $TagStack[0] eq "colour"
           or $TagStack[0] eq "length"
	  ) {
    }
    else
    {
	warn "unknown tag $TagStack[0]";
    }
}

sub Default {
    my( $parseinst, $data ) = @_;
    # you could do something here
}

sub usage()
{
    die "$0: $0 --file <input_filename> [--quite]\n";
}
