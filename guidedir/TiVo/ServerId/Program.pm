package TiVo::ServerId::Program;

use strict;
use base qw(TiVo::ServerId);

our $VERSION =
    (split / /, q$Id: Program.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

my $base = 100_000_000;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->_base($base);
    return $self;
}

1;
