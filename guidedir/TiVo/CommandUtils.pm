package TiVo::CommandUtils;

use strict;
use warnings;
use base 'Exporter';
use Carp;
use Date::Calc qw(Delta_Days Add_Delta_Days);

our @EXPORT_OK = qw(range);
our $VERSION =
    (split / /, q$Id: CommandUtils.pm,v 1.2 2003/06/24 03:34:26 darren Exp $)[2];

sub range {
    my $rangestr = shift;
    my %options = @_;
    my @ranges = split(/,/, $rangestr);
    return map { subrange($_, %options) } @ranges;
}

sub subrange {
    my $rangestr = shift;
    my %options = @_;           # 'date' is the only options right now
    if ($rangestr =~ /\-/) {     # eg, 1100028-35
        my ($start, $partialend) = split(/\-/, $rangestr);
        number_check($start, $partialend);
        my $end = $start;
        my $endlength = length($partialend);
        substr($end, -$endlength, $endlength, $partialend);
        if ($options{date}) {
            return date_range($start, $end);
        }
        else {
            return $start .. $end;
        }
    }
    elsif ($rangestr =~ /\+/) {
        my ($start, $plus) = split(/\+/, $rangestr);
        number_check($start, $plus);
        if ($options{date}) {
            return date_plus($start, $plus);
        }
        else {
            return $start .. ($start + $plus);
        }
    }
    else {
        number_check($rangestr);
        return $rangestr;
    }
}
        
sub number_check {
    for my $number (@_) {
        croak "bad range" if $number =~ /\D/;
    }
}   

sub date_from_string {
    my $str = shift;
    $str =~ /(\d{4})(\d{2})(\d{2})/ or croak "bad date";
    return [$1, $2, $3];
}

sub date_range {
    my ($start, $end) = @_;
    $start = date_from_string($start) unless ref $start;
    $end = date_from_string($end) unless ref $end;

    my @date = @$start;
    my @dates = $start; 
    my $i = Delta_Days(@$start, @$end);
    while ($i-- > 0) {
        @date = Add_Delta_Days(@date, 1);
        # pad month and day
        $date[1] = sprintf("%02d", $date[1]);
        $date[2] = sprintf("%02d", $date[2]);
        push @dates, [ @date ];
    }
    
    return map { join '', @$_ } @dates;
}

sub date_plus {
    my ($start, $plus) = @_;
    $start = date_from_string($start) unless ref $start;
    my @end = Add_Delta_Days(@$start, $plus);
    return date_range($start, \@end);
}
