package Data::Plist::BinaryReader;

use strict;
use warnings;

use base qw/Data::Plist::Reader/;
use Data::Plist;

use Encode qw(decode);
use Fcntl qw(:seek);
use Math::BigInt;

sub read_misc {
    my $self = shift;

    my ($type) = @_;
    if ( $type == 0 ) {
        return [ "null", 0 ];
    }
    elsif ( $type == 8 ) {
        return [ "false", 0 ];
    }
    elsif ( $type == 9 ) {
        return [ "true", 1 ];
    }
    elsif ( $type == 15 ) {
        return [ "fill", 15 ];
    }
    else {
        return [ "???", $type ];
    }
}

sub read_integer {
    my $self = shift;
    my ($size) = @_;

    my ( $buf, $val );
    read( $self->{fh}, $buf, 1 << $size );
    if ( $size == 0 ) {    # 8 bit
        $val = unpack( "C", $buf );
    }
    elsif ( $size == 1 ) {    # 16 bit
        $val = unpack( "n", $buf );
    }
    elsif ( $size == 2 ) {    # 32 bit
        $val = unpack( "N", $buf );
    }
    elsif ( $size == 3 ) {    # 64 bit

        my ( $hw, $lw ) = unpack( "NN", $buf );
        $val = Math::BigInt->new($hw)->blsft(32)->bior($lw);
        if ( $val->bcmp( Math::BigInt->new(2)->bpow(63) ) > 0 ) {
            $val -= Math::BigInt->new(2)->bpow(64);
        }
    }
    else {
        die "Invalid size for integer ($size)";
    }

    return [ "integer", $val ];
}

sub read_real {
    my $self = shift;
    my ($size) = @_;

    my ( $buf, $val );
    read( $self->{fh}, $buf, 1 << $size );
    if ( $size == 2 ) {    # 32 bit
        $val = unpack( "f", reverse $buf );
    }
    elsif ( $size == 3 ) {    # 64 bit
        $val = unpack( "d", reverse $buf );
    }
    else {
        die "Invalid size for real ($size)";
    }

    return [ "real", $val ];
}

sub read_date {
    my $self = shift;
    my ($size) = @_;
    die "Invalid size for date ($size)"
      if ( $size > 3 or $size < 2 );

    # Dates are just stored as floats
    return [ "date", $self->read_real($size)->[1] ];
}

sub read_data {
    my $self = shift;
    my ($size) = @_;

    my $buf;
    read( $self->{fh}, $buf, $size );

    # Binary data is often a binary plist!  Unpack it.
    if ( $buf =~ /^bplist00/ ) {
        $buf = eval { ( ref $self )->open_string($buf) } || $buf;
    }

    return [ "data", $buf ];
}

sub read_string {
    my $self = shift;
    my ($size) = @_;

    my $buf;
    read( $self->{fh}, $buf, $size );

    $buf = pack "U0C*", unpack "C*", $buf;    # mark as Unicode

    return [ "string", $buf ];
}

sub read_ustring {
    my $self = shift;
    my ($size) = @_;

    my $buf;
    read( $self->{fh}, $buf, 2 * $size );

    return [ "ustring", decode( "UTF-16BE", $buf ) ];
}

sub read_refs {
    my $self = shift;
    my ($count) = @_;
    my $buf;
    read( $self->{fh}, $buf, $count * $self->{refsize} );
    return unpack( ( $self->{refsize} == 1 ? "C*" : "n*" ), $buf );
}

sub read_array {
    my $self = shift;
    my ($size) = @_;

    return [ "array",
        [ map { $self->binary_read($_) } $self->read_refs($size) ] ];
}

sub read_dict {
    my $self = shift;
    my ($size) = @_;
    my %dict;

    # read keys
    my @keys = $self->read_refs($size);
    my @objs = $self->read_refs($size);

    for my $j ( 0 .. $#keys ) {
        my $key = $self->binary_read( $keys[$j] );
        die "Key of hash isn't a string!" unless $key->[0] eq "string";
        $key = $key->[1];
        my $obj = $self->binary_read( $objs[$j] );
        $dict{$key} = $obj;
    }

    return [ "dict", \%dict ];
}

sub read_uid {
    my $self = shift;
    my ($size) = @_;

    # UIDs are stored internally identically to ints
    my $v = $self->read_integer($size)->[1];
    return [ UID => $v ];
}

sub binary_read {
    my $self = shift;
    my ($objNum) = @_;

    if ( defined $objNum ) {
        die "Bad offset: $objNum"
          unless $objNum < @{ $self->{offsets} };
        seek( $self->{fh}, $self->{offsets}[$objNum], SEEK_SET );
    }

    # get object type/size
    my $buf;
    read( $self->{fh}, $buf, 1 )
      or die "Can't read type byte: $!\byte:";

    my $size    = unpack( "C*", $buf ) & 0x0F;    # Low nybble is size
    my $objType = unpack( "C*", $buf ) >> 4;      # High nybble is type
    $size = $self->binary_read->[1]
      if $objType != 0 and $size == 15;

    my %types = (
        0  => "misc",
        1  => "integer",
        2  => "real",
        3  => "date",
        4  => "data",
        5  => "string",
        6  => "ustring",
        8  => "uid",
        10 => "array",
        13 => "dict",
    );

    die "Unknown type $objType" unless $types{$objType};
    my $method = "read_" . $types{$objType};
    die "Can't $method" unless $self->can($method);
    return $self->$method($size);
}

sub open_string {
    my $self = shift;
    my ($str) = @_;

    # Seeking in in-memory filehandles can cause perl 5.8.8 to explode
    # with "Out of memory" or "panic: memory wrap"; Do some
    # error-proofing here.
    die "Not a binary plist file\n"
      unless length $str >= 8 and substr( $str, 0, 8 ) eq "bplist00";
    die "Read of plist trailer failed\n"
      unless length $str >= 40;
    die "Invalid top object identifier\n"
      unless length $str > 40;

    return $self->SUPER::open_string($str);
}

sub open_fh {
    my $self = shift;
    $self = $self->new() unless ref $self;

    my ($fh) = @_;

    my $buf;
    $self->{fh} = $fh;
    seek( $self->{fh}, 0, SEEK_SET );
    read( $self->{fh}, $buf, 8 );
    unless ( $buf eq "bplist00" ) {
        die "Not a binary plist file\n";
    }

    # get trailer
    eval { seek( $self->{fh}, -32, SEEK_END ) }
      or die "Read of plist trailer failed\n";
    my $end = tell( $self->{fh} );

    die "Read of plist trailer failed\n"
      unless $end >= 8;

    unless ( read( $self->{fh}, $buf, 32 ) == 32 ) {
        die "Read of plist trailer failed\n";
    }
    local $self->{refsize};
    my ( $OffsetSize, $NumObjects, $TopObject, $OffsetTableOffset );
    (
        $OffsetSize, $self->{refsize}, $NumObjects, $TopObject,
        $OffsetTableOffset
    ) = unpack "x6CC(x4N)3", $buf;

    # Sanity check the trailer
    if ( $OffsetSize < 1 or $OffsetSize > 4 ) {
        die "Invalid offset size\n";
    }
    elsif ( $self->{refsize} < 1 or $self->{refsize} > 2 ) {
        die "Invalid reference size\n";
    }
    elsif ( 2**( 8 * $self->{refsize} ) < $NumObjects ) {
        die
"Reference size (@{[$self->{refsize}]}) is too small for purported number of objects ($NumObjects)\n";
    }
    elsif ( $TopObject >= $NumObjects ) {
        die "Invalid top object identifier\n";
    }
    elsif ($OffsetTableOffset < 8
        or $OffsetTableOffset > $end
        or $OffsetTableOffset + $NumObjects * $OffsetSize > $end )
    {
        die "Invalid offset table address (overlap with header or footer).";
    }

    # get the offset table
    seek( $fh, $OffsetTableOffset, SEEK_SET );

    my $offsetTable;
    my $readSize = read( $self->{fh}, $offsetTable, $NumObjects * $OffsetSize );
    if ( $readSize != $NumObjects * $OffsetSize ) {
        die "Offset table read $readSize bytes, expected ",
          $NumObjects * $OffsetSize;
    }

    my @Offsets =
      unpack( [ "", "C*", "n*", "(H6)*", "N*" ]->[$OffsetSize], $offsetTable );
    if ( $OffsetSize == 3 ) {
        @Offsets = map { hex($_) } @Offsets;
    }

    # Catch invalid offset addresses in the offset table
    if (
        grep {
                 $_ < 8
              or $_ >= $end
              or (  $_ >= $OffsetTableOffset
                and $_ < $OffsetTableOffset + $NumObjects * $OffsetSize )
        } @Offsets
      )
    {
        die "Invalid address in offset table\n";
    }

    local $self->{offsets} = \@Offsets;

    my $top = $self->binary_read($TopObject);
    close($fh);

    return Data::Plist->new( data => $top );
}

sub convert_int {
    my $self = shift;
    my ($int) = @_;
    if ( $int == 8 ) {
        return 4;
    }
    elsif ( $int == 4 ) {
        return 3;
    }
    else {
        return $int;
    }
}

1;
