package Data::Plist::BinaryReader;

use strict;
use warnings;

use Encode qw(decode);
use Fcntl qw(:seek);
use Math::BigInt;
use MIME::Base64;

sub new {
    my $class = shift;
    return bless { offsets => [], refsize => undef } => $class;
}

sub read_misc {
    my $self = shift;

    my ($objLen) = @_;
    if ( $objLen == 0 ) {
        return [ "null", 0 ];
    } elsif ( $objLen == 8 ) {
        return [ "false", 0 ];
    } elsif ( $objLen == 9 ) {
        return [ "true", 1 ];
    } elsif ( $objLen == 15 ) {
        return [ "fill", 15 ];
    }
}

sub read_int {    # int
    my $self = shift;

    my ($objLen) = @_;
    die "Integer > 8 bytes = $objLen" if ( $objLen > 3 );

    my $byteLen = 1 << $objLen;

    my ( $buf, $val );
    read( $self->{fh}, $buf, $byteLen );
    if ( $objLen == 0 ) {
        $val = unpack( "C", $buf );
    } elsif ( $objLen == 1 ) {
        $val = unpack( "n", $buf );
    } elsif ( $objLen == 2 ) {
        $val = unpack( "N", $buf );
    } elsif ( $objLen == 3 ) {

        my ( $hw, $lw ) = unpack( "NN", $buf );
        $val = Math::BigInt->new($hw)->blsft(32)->bior($lw);
        if ( $val->bcmp( Math::BigInt->new(2)->bpow(63) ) > 0 ) {
            $val -= Math::BigInt->new(2)->bpow(64);
        }
    }

    return [ "int", $val ];
}

sub read_real {    # real
    my $self = shift;
    my ($objLen) = @_;
    die "Real > 8 bytes" if ( $objLen > 3 );

    my $byteLen = 1 << $objLen;

    my ( $buf, $val );
    read( $self->{fh}, $buf, $byteLen );
    if ( $objLen == 0 ) {         # 1 byte float = error?
        die "1 byte real found";
    } elsif ( $objLen == 1 ) {    # 2 byte float???
        die "2 byte real found";
    } elsif ( $objLen == 2 ) {
        $val = unpack( "f", reverse $buf );
    } elsif ( $objLen == 3 ) {
        $val = unpack( "d", reverse $buf );
    }

    return [ "real", $val ];
}

sub read_date {
    my $self = shift;
    my ($objLen) = @_;
    die "Date > 8 bytes" if ( $objLen > 3 );

    my $byteLen = 1 << $objLen;

    my ( $buf, $val );
    read( $self->{fh}, $buf, $byteLen );
    if ( $objLen == 0 ) {         # 1 byte NSDate = error?
        die "1 byte NSDate found";
    } elsif ( $objLen == 1 ) {    # 2 byte NSDate???
        die "2 byte NSDate found";
    } elsif ( $objLen == 2 ) {
        $val = unpack( "f", reverse $buf );
    } elsif ( $objLen == 3 ) {
        $val = unpack( "d", reverse $buf );
    }

    return [ "date", $val ];
}

sub read_data {
    my $self = shift;
    my ($byteLen) = @_;

    my $buf;
    read( $self->{fh}, $buf, $byteLen );

    # Binary data is often a binary plist!  Unpack it.
    if ( $buf =~ /^bplist00/ ) {
        $buf = eval { (ref $self)->open_string($buf) } || $buf;
    }

    return [ "data", $buf ];
}

sub read_string {
    my $self = shift;
    my ($objLen) = @_;

    my $buf;
    read( $self->{fh}, $buf, $objLen );

    $buf = pack "U0C*", unpack "C*", $buf;    # mark as Unicode

    return [ "string", $buf ];
}

sub read_ustring {
    my $self = shift;
    my ($objLen) = @_;

    my $buf;
    read( $self->{fh}, $buf, 2 * $objLen );

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
    my ($objLen) = @_;

    return [
        "array", [ map { $self->binary_read($_) } $self->read_refs($objLen) ]
    ];
}

sub read_dict {
    my $self = shift;
    my ($objLen) = @_;
    my %dict;

    # read keys
    my @keys = $self->read_refs($objLen);
    my @objs = $self->read_refs($objLen);

    for my $j ( 0 .. $#keys ) {
        my $key = $self->binary_read( $keys[$j] );
        die "Type isn't string!" unless $key->[0] eq "string";
        $key = $key->[1];
        my $obj = $self->binary_read( $objs[$j] );
        $dict{$key} = $obj;
    }

    return [ "dict", \%dict ];
}

sub read_uid {
    my $self = shift;
    my ($objLen) = @_;

    # UIDs are stored internally identically to ints
    my $v = $self->read_int($objLen)->[1];
    return [ UID => $v ];;
}

sub binary_read {
    my $self = shift;
    my ($objNum) = @_;

    seek( $self->{fh}, $self->{offsets}[$objNum], SEEK_SET )
        if defined $objNum;

    # get object type/size
    my $buf;

    if ( read( $self->{fh}, $buf, 1 ) != 1 ) {
        die "Didn't read type byte: $!";
    }
    my $objLen = unpack( "C*", $buf ) & 0xF;
    $buf = unpack( "H*", $buf );
    my $objType = substr( $buf, 0, 1 );
    if ( $objType ne "0" && $objType ne "8" && $objLen == 15 ) {
        $objLen = $self->binary_read->[1];
    }

    my %types = (
        0 => "misc",
        1 => "int",
        2 => "real",
        3 => "date",
        4 => "data",
        5 => "string",
        6 => "ustring",
        8 => "uid",
        a => "array",
        d => "dict",
    );

    return [ "??? $objType ???", undef ] unless $types{$objType};
    my $method = "read_" . $types{$objType};
    die "Can't $method" unless $self->can($method);
    my $v = $self->$method($objLen);
    return $v;
}

sub open_string {
    my $self = shift;
    my ($content) = @_;

    my $fh;
    open( $fh, "<", \$content );
    return $self->open_fh($fh);
}

sub open_file {
    my $self = shift;
    my ($filename) = @_;

    my $fh;
    open( $fh, "<", $filename ) or die "can't open $filename for conversion";
    binmode($fh);
    return $self->open_fh($fh);
}

sub open_fh {
    my $self = shift;
    $self = $self->new() unless ref $self;

    my ($fh) = @_;

    $self->{fh} = $fh;

    # get trailer
    seek( $self->{fh}, -32, SEEK_END );
    my $buf;
    read( $self->{fh}, $buf, 32 );
    my ( $OffsetSize, $NumObjects, $TopObject, $OffsetTableOffset );
    (   $OffsetSize, $self->{refsize}, $NumObjects, $TopObject,
        $OffsetTableOffset
    ) = unpack "x6CC(x4N)3", $buf;

    # get the offset table
    seek( $fh, $OffsetTableOffset, SEEK_SET );

    my $rawOffsetTable;
    my $readSize
        = read( $self->{fh}, $rawOffsetTable, $NumObjects * $OffsetSize );
    if ( $readSize != $NumObjects * $OffsetSize ) {
        die "rawOffsetTable read $readSize expected ",
            $NumObjects * $OffsetSize;
    }

    my @Offsets = unpack( [ "", "C*", "n*", "(H6)*", "N*" ]->[$OffsetSize],
        $rawOffsetTable );
    if ( $OffsetSize == 3 ) {
        @Offsets = map { hex($_) } @Offsets;
    }
    $self->{offsets} = \@Offsets;

    my $top = $self->binary_read($TopObject);
    close($fh);

    return Data::Plist->new( data => $top );
}

1;
