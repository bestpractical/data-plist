package Data::Plist::BinaryWriter;

use strict;
use warnings;

use base qw/Data::Plist::Writer/;

sub write_fh {
    my $self = shift;
    $self = $self->new() unless ref $self;

    my ( $fh, $object ) = @_;
    binmode $fh;
    $self->{fh}    = $fh;
    $self->{index} = [];
    $self->{size}  = $self->count($object);
    if ( $self->{size} >= 2**8 ) {
        $self->{refsize} = 2;
    }
    else {
        $self->{refsize} = 1;
    }
    print $fh "bplist00";

    return 1;
}

sub binary_write {
    my $self = shift;
    my @ref;
}

sub dispatch {
    my $self       = shift;
    my ($arrayref) = @_;
    my $type       = $arrayref->[0];
    my $method     = "write_" . $type;
    die "Can't $method" unless $self->can($method);
    return $self->$method( $arrayref->[1] );
}

sub make_type {
    my $self = $shift;
    my ( $typ, $len ) = @_;
    my $ans = "";

    my $optint = "";

    if ( $len < 15 ) {
        $typ .= sprintf( "%x", $len );
    }
    else {
        $typ .= "f";
        $optint = MakeInt($len);
    }
    $ans = pack( "H*", $typ ) . $optint;

    return $ans;
}

sub write_int {
    my $self = shift;
    my ( $int, $type ) = @_;
    my $ans = "";

    unless ( defined $type ) {
        $type = 1;
    }
    if ( $int > 65535 ) {    # 4 byte int
        $ans = "\x" . $type "2" . pack( "N", $int );
    }
    elsif ( $int > 255 ) {    # 2 byte int
        $ans = "\x" . $type "1" . pack( "n", $int );
    }
    else {
        $ans = "\x" . $type "0" . pack( "C", $int );
    }

    my $current = tell $fh;
    print $fh $ans;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_string {
    my $self = shift;
    my ($string) = @_;

    my $type = make_type( "5", length($string) );
    my $obj = $type . pack( "U", $string );
    my $current = tell $fh;
    print $fh $obj;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_ustring {
    my $self = shift;
    return $self->write_string(@_);
}

sub write_dict {
    my $self = shift;
    my ($hash) = @_;
    my @keys;
    my @values;
    for my $key ( keys %$hash ) {
        push @keys, $self->dispatch( [ "string", $key ] );
        push @values, $self->dispatch( $hash->{$key} );
    }
    my $current = tell $fh;
    print $fh make_type( "d", scalar keys(%$hash) );
    my $packvar;
    if ( $self->{refsize} = 2 ) {    # 4 byte int
        $packvar = "n";
    }
    else {
        $packvar = "C";
    }
    print $fh pack $packvar, $_ for @keys, @values;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_array {
    my $self    = shift;
    my ($array) = @_;
    my $size    = @$array;
    my @values;
    for (@$array) {
        push @values, $self->dispatch($_);
    }
    my $current = tell $fh;
    print $fh make_type( "a", $size );
    my $packvar;
    if ( $self->{refsize} = 2 ) {    # 4 byte int
        $packvar = "n";
    }
    else {
        $packvar = "C";
    }
    print $fh pack $packvar, $_ for @values;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_uid {
    my $self    = shift;
    my ($id)    = @_;
    my $obj     = make_int( $value, "8" );
    my $current = tell $fh;
    print $fh $obj;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub count {
    my ($arrayref) = @_;
    my $type = $arrayref->[0];
    if ( $type eq "dict" ) {
        my @keys  = keys $arrayref->[1];
        my $value = 1 + @keys;
        $value += $_ for map { $self->count( $arrayref->[1]->{$_} ) } @keys;
        return $value;
    }
    elsif {
        my $value = 1;
        $value += $_ for map { $self->count($_) } @$arrayref;
        return $value;
    }
    else {
        return 1;
    }
}

1;
