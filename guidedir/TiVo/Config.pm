package TiVo::Config;

use strict;
use Carp;

our $VERSION =
    (split / /, q$Id: Config.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    #my $home = (getpwuid($<))[7] || $ENV{HOME} || '.';
    #my $conffile = "$home/.tivoguiderc";
    my $conffile = ".tivoguiderc";
    croak "no config file found (looking for $conffile)" unless -e $conffile;
    $self->{file} = $conffile;
    $self->load;
    return $self;
}

sub load {
    my $self = shift;
    my $conffile = $self->{file};
    open(my $file, $conffile) or die "failed to open config ($!)";
    while (<$file>) {
        push @{$self->{lines}}, $_; # save all the lines for later saving
        next if /^\s*\#/;       # skip comment lines
        next if /^\s*$/;        # skip blank lines
        chomp;
        s/\#.*$//;              # remove end-of-line comments
        my ($key, $value) = split /\s*=\s*/;
        $value =~ s/\s*$//;
        $self->{conf}->{$key} = $value;
    }
    close($file) or die "failed to close config ($!)";
    $self->{changed} = 0;
}

sub save {
    my $self = shift;
    return unless $self->{changed};
    my $conffile = $self->{file};
    open (my $file, ">$conffile") 
        or die "failed to open config for write ($!)";
    my %conf = %{$self->{conf}}; # copy it so we can delete keys
    for my $line (@{$self->{lines}}) {
        # rewrite config lines
        $line =~ s/^(\w+)\s*\=\s*([^\s\#]+)/"$1 = " . $conf{$1}/e
            and delete $conf{$1};
        print $file $line;
    }
    for my $key (sort keys %conf) {
        # remaining config values
        my $value = $conf{$key};
        print $file "$key = $value\n";
    }
    close($file) or die "failed to close config ($!)";
}

sub get {
    my $self = shift;
    my $key = shift;
    if (exists $self->{conf}->{$key}) {
        return $self->{conf}->{$key};
    }
    else {
        croak "'$key' is not in the config";
    }
}

sub set {
    my $self = shift;
    my ($key, $value) = @_;
    $self->{conf}->{$key} = $value;
    $self->{changed}++;
    return $value;
}

# get or set the short way
AUTOLOAD {
    my $self = shift;
    our $AUTOLOAD;
    my $key = $AUTOLOAD;
    $key =~ s/.*:://;
    if (my $value = shift) {
        $self->set($key, $value);
    }
    return $self->get($key);
}

# auto-save
DESTROY {
    my $self = shift;
    $self->save;
}

1;
