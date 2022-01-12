package TiVo::ServerId::StationDay;

use strict;
use base qw(TiVo::ServerId);

our $VERSION =
    (split / /, q$Id: StationDay.pm,v 1.3 2004/03/21 16:28:10 n4zmz Exp $)[2];

my $base = 300_000_000;

sub new {
    my $class = shift;
    my ($station, $day) = @_;

    # should probably override _calc for this
    my $value = (substr($station, -5) * 1_000) + $day;

    my $self = $class->SUPER::new($value);
    $self->_base($base);
    return $self;
}

1;
