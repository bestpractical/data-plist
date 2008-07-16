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
    my $top_index   = $self->dispatch($object);
    my $offset_size = 1;
    if ( $self->{index}->[-1] > 65535 ) {
        $offset_size = 4;
    }
    elsif ( $self->{index}->[-1] > 255 ) {
        $offset_size = 2;
    }
    my $table_offset = tell $fh;
    for (@$self->{index}){
	print $fh (pack ($self->pack_in($offset_size)), $_);
    }
    print $fh ( pack "x6CC", $offset_size, $self->{refsize} );
    print $fh ( pack "x4N", $self->{size} );
    print $fh ( pack "x4N", $top_index );
    print $fh ( pack "x4N", $table_offset );
    close $fh;
    return 1;
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
    my $self = shift;
    my ( $typ, $len ) = @_;
    my $ans = "";

    my $optint = "";

    if ( $len < 15 ) {
        $typ .= sprintf( "%x", $len );
    }
    else {
        $typ .= "f";
	my $optlen = $self->int_length($len);
	$optint = pack( "C" . $self->pack_in($optlen), hex("1" . $optlen), $len)
    }
    $ans = pack( "H*", $typ ) . $optint;

    return $ans;
}

sub write_int {
    my $self = shift;
    my ( $int, $type ) = @_;
    my $fmt;

    unless ( defined $type ) {
        $type = "1";
    }
    my $len = $self->int_length($int);
    $fmt = $self->pack_in($len);
    my $obj = "\x" . $type . $len . pack($fmt, $int);
    return $self->binary_write($obj);
}

sub write_string {
    my $self = shift;
    my ($string) = @_;

    my $type = $self->make_type( "5", length($string) );
    my $obj = $type . pack( "U", $string );
    return $self->binary_write($obj);
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
    my $current = tell $self->{fh};
    print $self->{fh}, $self->make_type( "d", scalar keys(%$hash) );
    my $packvar = $self->pack_in($self->{refsize});
    print $self->{fh}, pack $packvar, $_ for @keys, @values;
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
    my $current = tell $self->{fh};
    print $self->{fh}, $self->make_type( "a", $size );
    my $packvar = $self->pack_in($self->{refsize});
    print $self->{fh}, pack $packvar, $_ for @values;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_uid {
    my $self    = shift;
    my ($id)    = @_;
    return $self->write_int( $id, "8" );
}

sub write_real {
    my $self    = shift;
    my ($float) = @_;
    my $type    = $self->make_type( "2", 4 );
    my $obj     = $type . reverse( pack( "d", $float ) );
    return $self->binary_write($obj);
}

sub write_date {
    my $self    = shift;
    my ($date)  = @_;
    my $type    = $self->make_type( "3", 4 );
    my $obj     = $type . reverse( pack( "d", $date ) );
    return $self->binary_write($obj);
}

sub write_null {
    my $self = shift;
    return $self->write_misc( 0, @_ );
}

sub write_false {
    my $self = shift;
    return $self->write_misc( 8, @_ );
}

sub write_true {
    my $self = shift;
    return $self->write_misc( 9, @_ );
}

sub write_fill {
    my $self = shift;
    return $self->write_misc( 15, @_ );
}

sub write_misc {
    my $self = shift;
    my ( $type, $misc ) = @_;
    my $obj = $self->make_type( "0", $type );
    return $self->binary_write($obj);
}

sub count {
    my $self       = shift;
    my ($arrayref) = @_;
    my $type       = $arrayref->[0];
    my $value;
    if ( $type eq "dict" ) {
        my @keys = ( keys %{ $arrayref->[1] } );
        $value = 1 + @keys;
        $value += $_ for map { $self->count( $arrayref->[1]->{$_} ) } @keys;
        return $value;
    }
    elsif ( $type eq "array" ) {
        $value = 1;
        $value += $_ for map { $self->count($_) } @$arrayref;
        return $value;
    }
    else {
        return 1;
    }
}

sub binary_write{
    my $self = shift;
    my ($obj) = @_;
    my $current = tell $self->{fh};
    print $self->{fh}, $obj;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub int_length{
    my $self = shift;
    my ($int) = @_;
    if ( $int > 65535 ) {
        return 4;
    }
    elsif ( $int > 255 ) {
	return 2;
    }
    else {
	return 1;
    }
}

sub pack_in {
    my $self = shift;
    my ($bytes) = @_;
    my $fmt = ["C", "n", "N", "N"]->[$bytes-1];
    if ($bytes == 3) {
	die "Cannot encode 3 byte integers";
    }
    return $fmt;
}

1;
