#!/usr/bin/perl
#
#  $Id: scrapeLbxMovieCentral.pl,v 1.1 2004/08/28 22:12:29 pcrane Exp $
#

use strict;

# Add the program dir to the module search path
use FindBin qw($Bin);
use lib $Bin;

use Date::Manip;
use DBI;
use DDParserUtils;
use CGI;
use HTML::TokeParser;
use LWP::Simple;

print "****************************************\n";
print "* Starting scrapeLbxMovieCentral.pl\n";
print "****************************************\n";

our $Database = DDParserUtils::cfg_val("database","name","tvdata");
our $dBUser = DDParserUtils::cfg_val("database","user","dbuser");
our $dBPassword = DDParserUtils::cfg_val("database","password","dbpassword");
my $dbtype = DDParserUtils::cfg_val("database","type","mysql");
our $ConnectionStr = "dbi:$dbtype".":$Database";
our $connection = DBI->connect( $ConnectionStr, $dBUser, $dBPassword, {printerr=>0} ) or die $DBI::errstr;

my %GenericSQL;
$GenericSQL{STATIONS}->{SELECT} = $connection->prepare("SELECT station_id FROM Stations WHERE LOCATE(?,name)");
$GenericSQL{SCHEDULE}->{SELECT} = $connection->prepare("SELECT * FROM Schedule WHERE station_id=? AND schedule_day=? AND schedule_time=?");
$GenericSQL{LETTERBOX}->{UPDATE} = $connection->prepare("UPDATE Schedule SET letterbox=1 WHERE station_id=? AND schedule_day=? AND schedule_time=? AND (letterbox IS NULL OR letterbox=0)");

sub getFixedMTDate($)
{
    my $date = shift;
    my $tz = Date_TimeZone();
    my $mtTZ = "MST";
    if (defined($tz))
    {
        if ($tz =~ /DT$/)
        {
            $mtTZ = "MDT";
        }
    }
    $date =~ s/MT$/$mtTZ/;
    return &ParseDate($date);
}

sub getTivoDateTime($)
{
    my $date = shift;
    my $secs = &UnixDate($date,"%s");
    my $sched_day = $secs/86400;
    $sched_day =~ s/\..*//;
    my $sched_time = $secs - ($sched_day*86400);
    my @retval = ("$sched_day", "$sched_time");
    return @retval;
}

sub isLetterboxed($)
{
#(letter-box)
#(letterbox)
#(lettrbx)
#(ltr-box)
#(ltx)
#(subtitled)lb)
#5.1ltr
#Leterbox
#Letter-box)
#Lttrbx
    my $title = shift;
    if ($title =~ /\(letter-box\)/)
    {
        return 1;
    }
    elsif ($title =~ /\(letterbox\)/)
    {
        return 1;
    }
    elsif ($title =~ /\(lettrbx\)/)
    {
        return 1;
    }
    elsif ($title =~ /\(ltr-box\)/)
    {
        return 1;
    }
    elsif ($title =~ /\(ltx\)/)
    {
        return 1;
    }
    elsif ($title =~ /.+lb\)$/)
    {
        return 1;
    }
    elsif ($title =~ /.+5.1ltr$/)
    {
        return 1;
    }
    elsif ($title =~ /.+Leterbox$/)
    {
        return 1;
    }
    elsif ($title =~ /.+Letter-box\)$/)
    {
        return 1;
    }
    elsif ($title =~ /.+Lttrbx$/)
    {
        return 1;
    }
    return 0;
}
sub find_showings($$)
{
    my ($showID,$title) = @_;
    print "find_showings[$showID]: $title\n";
    my $show_fetchURL = "http://www.moviecentral.ca/cgi-bin/schedule2/show_nfo2.cgi?".$showID;;
    my $show_pageContents = get($show_fetchURL);
    my $show_stream = HTML::TokeParser->new(\$show_pageContents);
    while (my $token = $show_stream->get_token)
    {
        if ($token->[0] eq 'S' and $token->[1] eq 'td')
        {
            my $i = $token->[2]; # attributes of this TD tag
            if (defined($i->{'valign'}))
            {
                my $more = 1;
                while ($more)
                {
                    my $text = $show_stream->get_trimmed_text();
                    my $tag_ref = $show_stream->get_tag('br', '/td');
                    if ($text eq '' || $tag_ref->[0] eq 'E')
                    {
                        $more = 0;
                    } else {
                        $text =~ s/Noon/pm/;
                        $text =~ s/Midnight/am/;
                        $text =~ /(.+ [0-9]+ .+ [ap]m MT) (.+)$/;
                        if (defined($1) && defined($2))
                        {
                            markLetterbox($1, $2);
                        }
                        else
                        {
                            print STDERR "Failed parsing showing: $text\n";
                        }
                    }
                }
            }
        }
    }
}
sub getStationID($)
{
    my $stationName = shift;
    if ($GenericSQL{STATIONS}->{SELECT}->execute($stationName))
    {
        if (my $row = $GenericSQL{STATIONS}->{SELECT}->fetchrow_hashref())
        {
            return $row->{station_id};
        }
    }
    return undef;
}
sub markLetterbox($$)
{
    my ($showing, $stationName) = @_;
    my $stationID = getStationID($stationName);
    my $parsed = getFixedMTDate($showing);
    my ($sched_day, $sched_time) = getTivoDateTime($parsed);
    if ($GenericSQL{LETTERBOX}->{UPDATE}->execute($stationID,$sched_day,$sched_time))
    {
        my $rowsUpdated = $GenericSQL{LETTERBOX}->{UPDATE}->rows();
        if ($rowsUpdated > 0)
        {
            print "Updated $rowsUpdated for $stationID,$sched_day,$sched_time\n";
#        } else {
#            print "NOTHING for $stationID,$sched_day,$sched_time\n";
        }
    }
}

sub find_shows($)
{
    my $stream = shift;
    while (my $token = $stream->get_token)
    {
        if ($token->[0] eq 'S' and $token->[1] eq 'a')
        {
            my $i = $token->[2]; # attributes of this A tag
	    my $href = $i->{'href'};
            $href =~ /javascript:popUp\('show_nfo2.cgi\?([0-9]+)\s'\)/;
            if (defined($1))
            {
                my $title = $stream->get_text('/a');
                if (isLetterboxed($title))
                {
                    find_showings($1, $title);
                }
            }
        }
    }
}

my $fetchURL="http://www.moviecentral.ca/cgi-bin/schedule2/alpha_listing2.cgi";
my $pageContents = get($fetchURL);
my $stream = HTML::TokeParser->new(\$pageContents);

find_shows($stream);
