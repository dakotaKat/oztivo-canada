package TiVo::ServerId;

our $VERSION =
    (split / /, q$Id: ServerId.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

sub new {
    my $class = shift;
    my $value = shift;
    my $self = {};
    bless $self, $class;
    $self->{value} = $value;
    return $self;
}

sub _base {
    my $self = shift;
    my $base = shift;
    $self->{base} = $base;
}

sub _calc {
    my $self = shift;
    $self->{id} = $self->{base} + $self->{value};
}
    
sub value {
    my $self = shift;
    unless (exists $self->{id}) {
        $self->_calc;
    }
    return $self->{id};
}    
                
1;
