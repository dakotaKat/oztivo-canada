package TiVo::Show;

use strict;
use Carp;
use TiVo::Config;
use File::Path;

our $VERSION =
    (split / /, q$Id: Show.pm,v 1.8 2003/08/29 22:32:06 darren Exp $)[2];

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub get {
    my $self = shift;
    my $key = shift;
    return $self->{data}->{$key};
}

sub set {
    my $self = shift;
    my ($key, $value) = @_;
    ##convert accented letters to normal ones
    $value =~ tr [ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝßàáâãäåçèéêëìíîïñòóôõöøùúûüýÿ]
		 [AAAAAACEEEEIIIIDNOOOOOOUUUUYBaaaaaaceeeeiiiinoooooouuuuyy];    
    
    if(($key =~ /actor|genre/i) && defined($self->{data}->{$key})) {
	my $tmpval = $self->{data}->{$key};
	if( ref( $tmpval ) eq 'ARRAY' ) {
	    my %tmphash;
	    my $tmp;
	    foreach $tmp (@{$self->{data}->{$key}})
	    {
		$tmphash{$tmp} = 1;
	    } 
	    $tmphash{$value} = 1;
	    @{$self->{data}->{$key}} = sort keys(%tmphash);
	} else {
	    my @Arr = ();
	    push @Arr, $tmpval;
	    push @Arr, $value;
	    
	    $self->{data}->{$key} = \@Arr;
	}
    } else {
	$self->{data}->{$key} = $value;
    }
    $self->{changed}++;
    return $value;
}

# get or set the short way
AUTOLOAD {
    my $self = shift;
    our $AUTOLOAD;
    my $key = $AUTOLOAD;
    $key =~ s/.*:://;
    my $value = shift;
    if (defined $value) {
		$self->set($key, $value);
    }
    return $self->get($key);
}

sub save {
    my $self = shift;

    if( $self->station == "" ) { return; };

    my $conf = TiVo::Config->new;
    my $path = join('/',
		    $conf->guidedir,
		    'shows',
		    (defined($self->duration())?'':'incomplete'),
		    $self->day,
		    $self->station,
		    );
    mkpath($path);
    my $time = $self->time;

    open(my $file, ">$path/$time") or die "failed open for write ($!)";

    for my $key (sort keys %{$self->{data}}) {
        my $value = $self->{data}->{$key};
	if( ref( $value ) eq 'ARRAY' )
	{
	    foreach (@{$value})
	    {
		print $file "$key = $_\n";
	    }
	} else {
	    print $file "$key = $value\n";
	}
    }
    close($file) or die "failed close ($!)";
}

sub load {
    my $self = shift;
    my $Retcode = 1;
    unless (map(defined, $self->day, $self->station, $self->time)) {
        croak "Show load needs day, station, and time.";
    }
    my $conf = TiVo::Config->new;
    my $path = join(
                    '/',
                    $conf->guidedir,
                    'shows',
		    ( $self->incomplete() eq '1' )?'incomplete':'',
                    $self->day,
                    $self->station,
                    $self->time,
                   );
    my $file;
    if( !open($file, $path) )
    {
        if( $self->incomplete() ne '1' )
	{
	    die "failed open of $path ($!)";
	}
	$Retcode = 0;
    }
    while (<$file>) {
        next if /^\s*\#/;
        next if /^\s*$/;
        chomp;
	s/\r+$//;  # eliminate trailing CRs
        my ($key, $value) = split /\s*=\s*/;
        $self->set($key, $value);
    }
    if( $Retcode == 1 )
    {
	close($file) or die "failed close of $path ($!)";
    }
    return($Retcode);
}

1;
