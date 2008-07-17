use Test::More tests => 160;

use strict;
use warnings;

use Data::Plist::BinaryWriter;
use Data::Plist::BinaryReader;



my $in;
my $out;

# Empty dict
round_trip( {}, 42 );

# Dict containing stuff
round_trip( { 'kitteh' => 'Angleton', 'MoL' => 42, 'array' => ['Cthulhu'] },
    93 );

# Empty array
round_trip( [], 42 );

# Array containing stuff
round_trip( ['Cthulhu'], 52 );

# Negative integer
round_trip( -1, 50 );

# Small integer
round_trip( 42, 43 );

# Large integer
round_trip( 777, 44 );

# Even larger integer
round_trip( 141414, 46 );

# Ginormous integer
round_trip( 4294967296, 50 );

# Short string
round_trip( "kitteh", 48 );

# Long string (where long means "more than 15 characters")
round_trip( "The kyokeach is cute", 64 );

# Real number
round_trip(3.14159, 50);

# Negative real
round_trip(-1.985, 50);

# Date
round_trip(DateTime->new(year => 2008, month => 7, day => 23), 50);

# Caching
round_trip({'kitteh' => 'Angleton', 'Laundry' => 'Angleton'}, 73);

# UIDs
preserialized_trip( [  UID => 1 ], 43 );

# Miscs
preserialized_trip([ false => 0 ], 42);
preserialized_trip([ true => 1 ], 42);
preserialized_trip([ fill => 15 ], 44);
preserialized_trip([ null => 0 ], 42);

sub round_trip {
    my $write = Data::Plist::BinaryWriter->new;
    my $read  = Data::Plist::BinaryReader->new;
    ok( $write, "Created a binary writer" );
    isa_ok( $write, "Data::Plist::BinaryWriter" );
    my ( $input, $expected_size ) = @_;
    $out = $write->write($input);
    ok( $out, "Created data structure" );
    like( $out, qr/^bplist00/, "Bplist begins with correct header" );
    is( length($out), $expected_size,
        "Bplist is " . $expected_size . " bytes long." );
    $in = eval { $read->open_string($out) };
    ok( $in, "Read back bplist" );
    isa_ok( $in, "Data::Plist" );
    is_deeply( $in->data, $input, "Read back " . $input );
}

sub preserialized_trip {
    my $write = Data::Plist::BinaryWriter->new(serialize => 0);
    my $read  = Data::Plist::BinaryReader->new;
    ok( $write, "Created a binary writer" );
    isa_ok( $write, "Data::Plist::BinaryWriter" );
    my ( $input, $expected_size ) = @_;
    $out = $write->write($input);
    ok( $out, "Created data structure" );
    like( $out, qr/^bplist00/, "Bplist begins with correct header" );
    is( length($out), $expected_size,
        "Bplist is " . $expected_size . " bytes long." );
    $in = eval { $read->open_string($out) };
    ok( $in, "Read back bplist" );
    isa_ok( $in, "Data::Plist" );
    is_deeply( $in->raw_data, $input, "Read back " . $input );
}
