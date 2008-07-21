package Data::Plist::BinaryWriter;

use strict;
use warnings;
use Storable;
use Math::BigInt;
use Digest::MD5;

use base qw/Data::Plist::Writer/;

sub write_fh {
    my $self = shift;
    $self = $self->new() unless ref $self;

    my ( $fh, $object ) = @_;
    $object = $self->serialize($object) if ( $self->{serialize} );
    binmode $fh;
    $self->{fh}       = $fh;
    $self->{index}    = [];
    $self->{size}     = $self->count($object);
    $self->{objcache} = {};
    if ( $self->{size} >= 2**8 ) {
        $self->{refsize} = 2;
    }
    else {
        $self->{refsize} = 1;
    }
    print $fh "bplist00";
    my $top_index    = $self->dispatch($object);
    my $offset_size  = $self->int_length( $self->{index}->[-1] );
    my $table_offset = tell $fh;
    for ( @{ $self->{index} } ) {
        print $fh ( pack $self->pack_in($offset_size), $_ );
    }
    print $fh ( pack "x6CC", ( $offset_size + 1 ), $self->{refsize} );
    print $fh ( pack "x4N", scalar keys %{ $self->{objcache} } );
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
    my $digest = eval{Digest::MD5::md5_hex( Storable::freeze( $arrayref ) )};
    die "Can't $method" unless $self->can($method);
    $self->{objcache}{$digest} = $self->$method( $arrayref->[1] )
      unless ( exists $self->{objcache}{$digest} );
    return $self->{objcache}{$digest};
}

sub make_type {
    my $self = shift;
    my ( $type, $len ) = @_;
    my $ans = "";

    my $optint = "";

    if ( $len < 15 ) {
        $type .= sprintf( "%x", $len );
    }
    else {
        $type .= "f";
        my $optlen = $self->int_length($len);
        $optint =
          pack( "C" . $self->pack_in($optlen), hex( "1" . $optlen ), $len );
    }
    $ans = pack( "H*", $type ) . $optint;

    return $ans;
}

sub write_integer {
    my $self = shift;
    my ( $int, $type ) = @_;
    my $fmt;
    my $obj;

    unless ( defined $type ) {
        $type = "1";
    }
    my $len = $self->int_length($int);

    if ( $len == 3 ) {
        if ( $int < 0 ) {
            $int += Math::BigInt->new(2)->bpow(64);
        }
        my $hw = Math::BigInt->new($int);
        $hw->brsft(32);
        my $lw = Math::BigInt->new($int);
        $lw->band( Math::BigInt->new("4294967295") );

        $obj =
          $self->make_type( $type, $len ) . pack( "N", $hw ) . pack( "N", $lw );
    }
    else {
        $fmt = $self->pack_in($len);
        $obj = pack( "C" . $fmt, hex( $type . $len ), $int );
    }
    return $self->binary_write($obj);
}

sub write_string {
    my $self     = shift;
    my ($string) = @_;
    my $type     = $self->make_type( "5", length($string) );
    my $obj      = $type . $string;
    return $self->binary_write($obj);
}

sub write_ustring {
    my $self = shift;
    return $self->write_string(@_);
}

sub write_dict {
    my $self   = shift;
    my $fh     = $self->{fh};
    my ($hash) = @_;
    my @keys;
    my @values;
    for my $key ( keys %$hash ) {
        push @keys, $self->dispatch( [ "string", $key ] );
        push @values, $self->dispatch( $hash->{$key} );
    }
    my $current = tell $self->{fh};
    print $fh $self->make_type( "d", scalar keys(%$hash) );
    my $packvar = $self->pack_in( $self->{refsize} - 1 );
    print $fh pack $packvar, $_ for @keys, @values;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_array {
    my $self    = shift;
    my $fh      = $self->{fh};
    my ($array) = @_;
    my $size    = @$array;
    my @values;
    for (@$array) {
        push @values, $self->dispatch($_);
    }
    my $current = tell $self->{fh};
    print $fh $self->make_type( "a", $size );
    my $packvar = $self->pack_in( $self->{refsize} - 1 );
    print $fh pack $packvar, $_ for @values;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub write_UID {
    my $self = shift;
    my ($id) = @_;
    return $self->write_integer( $id, "8" );
}

sub write_real {
    my $self    = shift;
    my ($float) = @_;
    my $type    = $self->make_type( "2", 3 );
    my $obj     = $type . reverse( pack( "d", $float ) );
    return $self->binary_write($obj);
}

sub write_date {
    my $self   = shift;
    my ($date) = @_;
    my $type   = $self->make_type( "3", 3 );
    my $obj    = $type . reverse( pack( "d", $date ) );
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

sub write_data {
    my $self = shift;
    my ($data) = @_;
    use bytes;
    my $len = length $data;
    my $obj = $self->make_type( 4, $len ) . $data;
    return $self->binary_write($obj);
}

sub count {

    # this might be slightly over, since it doesn't take into account duplicates
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
        $value += $_ for map { $self->count($_) } @{ $arrayref->[1] };
        return $value;
    }
    else {
        return 1;
    }
}

sub binary_write {
    my $self    = shift;
    my $fh      = $self->{fh};
    my ($obj)   = @_;
    my $current = tell $self->{fh};
    print $fh $obj;
    push @{ $self->{index} }, $current;
    return ( @{ $self->{index} } - 1 );
}

sub int_length {
    my $self = shift;
    my ($int) = @_;
    if ( $int > 4294967295 ) {
        return 3;

        # actually refers to 2^3 bytes
    }
    elsif ( $int > 65535 ) {
        return 2;

        # actually refers to 2^2 bytes
    }
    elsif ( $int > 255 ) {
        return 1;

        # I'm sure you see the trend
    }
    elsif ( $int < 0 ) {
        return 3;
    }
    else {
        return 0;
    }
}

sub pack_in {
    my $self = shift;
    my ($power) = @_;
    if ( $power == 4 ) {
        die "Cannot encode 2**4 byte integers";
    }
    my $fmt = [ "C", "n", "N", "N" ]->[$power];
    return $fmt;
}

1;
