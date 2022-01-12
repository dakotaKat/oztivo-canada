# returns the shows for a stationday
package TiVo::Shows;

use strict;
use TiVo::Config;
use TiVo::Show;
use Carp;

our $VERSION =
    (split / /, q$Id: Shows.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{shows} = [];
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    my %args = @_;

    my $conf = TiVo::Config->new;
    my $guide = $conf->guidedir;

    my $day = $self->{day} = $args{day};
    my $station = $self->{station} = $args{station};

    for my $time (sorted_filenames("$guide/shows/$day/$station")) {
        my $show = TiVo::Show->new;
        $show->day($day);
        $show->station($station);
        $show->time($time);
        $show->load;
        push @{$self->{shows}}, $show;
    }
}

sub station {
    my $self = shift;
    return $self->{station};
}

sub day {
    my $self = shift;
    return $self->{day};
}                      

# returns a list of TiVo::Show objects
sub all {
    my $self = shift;
    return @{$self->{shows}};
}

sub sorted_filenames {
    my $dir = shift;
    opendir(DIR, $dir) or confess "failed opendir of $dir ($!)";
    my @files = sort({ $a <=> $b } 
                     grep(!/^\.\.?$/, readdir(DIR)));
    closedir(DIR) or confess "failed closedir of $dir ($!)";
    return @files;
}

1;
