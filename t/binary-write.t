use Test::More no_plan => 1;

use strict;
use warnings;

use Data::Plist::BinaryWriter;
use Data::Plist::BinaryReader;



my $in;
my $out;

# Create the object
my $write = Data::Plist::BinaryWriter->new;
my $read  = Data::Plist::BinaryReader->new;
ok( $write, "Created a binary writer" );
isa_ok( $write, "Data::Plist::BinaryWriter" );

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
round_trip(DateTime->new(year => 2001, month => 1, day => 17), 50);

sub round_trip {
    my ( $input, $expected_size ) = @_;
    $out = $write->write($input);
    ok( $out, "Created data structure" );
    like( $out, qr/^bplist00/, "Bplist begins with correct header" );
    is( length($out), $expected_size,
        "Bplist is " . $expected_size . " bytes long." );
    $in = eval { $read->open_string($out) };
    is_deeply( $@, '' );
    ok( $in, "Read back bplist" );
    isa_ok( $in, "Data::Plist" );
    is_deeply( $in->data, $input, "Read back " . $input );
}
