package TiVo::ServerId::Series;

# this file by default uses GDBM_File to store and retrieve series id's
# if your system does not have this module you can try the DB_File 
# by commenting out the GDBM_File line and uncomment the DB_File lines.

use strict;
use GDBM_File;    # use GDBM_File or
# use DB_File;    # use DB_File not both
use base qw(TiVo::ServerId);
use vars qw(%series_table);

our $VERSION =
    (split / /, q$Id: Series.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

my $sidbase    = 200_000_000;   # regular series id
my $sidpidbase = 210_000_000;   # series id made from program id
                                # (for a program with no series)

my $series_file = "myseries";

my $base = 1000000;
my $maxid = $base-1;

tie (%series_table, "GDBM_File", $series_file, &GDBM_WRCREAT, 0644);  # comment this out if you don't have GDBM_File
# tie (%series_table, "DB_File", $series_file, O_RDWR|O_CREAT, 0666); # uncomment this if you want to use DB_File

sub new {
    my $class = shift;
    my $value = shift;
    my $title = shift;
    my $from_program = shift;
    my %options = {
                   @_,
                  };
    if( $series_table{"tivoguide_maxid"}  ) {
        # set maxid to this only if tivoguide_maxid is set in series_table
        $maxid = $series_table{"tivoguide_maxid"};
    }
    $title =~ s/\s+$//;
    # added to handle seriesid problem
    my $found_seriesid;
    $found_seriesid=$series_table{$title};
    if ($from_program && $found_seriesid eq "") {
	# get data from table
        my @line;
        # create new series id and update tivoguide_maxid
        $value=$maxid+1;
        $maxid=$value;
        $series_table{"tivoguide_maxid"} = $maxid;
        $series_table{$title}=$value;
        #print STDERR "'$title' using new sid of $value\n";
    } elsif ($from_program) {
        # use cached series id
    	$value=$found_seriesid;
        if(($value < $base) || ($value > $maxid)) {
            # for some reason series id was missing so use cached one
            #print STDERR "setting from_program to 0";
            $from_program = 0;
        }
        #print STDERR "'$title' using saved sid of $value\n";
    } elsif ($found_seriesid ne "") {
        $value=$found_seriesid;
        #print STDERR "'$title' using cached sid of $value\n";
    } else {
        # use Zap2it id and save it off
        $series_table{$title}=$value;
        #print STDERR "'$title' using Zap2it sid of $value\n";
    }

    my $self = $class->SUPER::new($value);
    if ($from_program) {
        $self->_base($sidpidbase);
    } else {
        $self->_base($sidbase);
    }
    return $self;
}

1;
