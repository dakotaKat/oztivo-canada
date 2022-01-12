package TiVo::ShowLists;

use strict;
use TiVo::Config;
use TiVo::Shows;
use Carp;

our $VERSION =
    (split / /, q$Id: ShowLists.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{showlists} = [];
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    my %args = @_;

    my $conf = TiVo::Config->new;
    my $guide = $conf->guidedir;
    my @days = $args{days} ? @{$args{days}} : sorted_filenames("$guide/shows");

    for my $day (@days) {
        my @allstations = sorted_filenames("$guide/shows/$day");
        my @stations = $args{stations} ? @{$args{stations}} : @allstations;
        for my $station (@stations) {
            my $shows = TiVo::Shows->new(day => $day, station => $station);
            push @{$self->{showlists}}, $shows;
        }
    }
}

# returns a list of TiVo::Shows objects
sub all {
    my $self = shift;
    return @{$self->{showlists}};
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
