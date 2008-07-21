use Test::More tests => 200;

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
round_trip( 3.14159, 50 );

# Negative real
round_trip( -1.985, 50 );

# Date
round_trip( DateTime->new( year => 2008, month => 7, day => 23 ), 50 );

# Caching
round_trip( { 'kitteh' => 'Angleton', 'Laundry' => 'Angleton' }, 73 );

# UIDs
preserialized_trip( [ UID => 1 ], 43 );

# Miscs
preserialized_trip( [ false => 0 ],  42 );
preserialized_trip( [ true  => 1 ],  42 );
preserialized_trip( [ fill  => 15 ], 44 );
preserialized_trip( [ null  => 0 ],  42 );

# Data
preserialized_trip ( [ data => "\x00"], 43);

my @array = [];
for (0 .. 299) {
    $array[$_] = $_;
}
round_trip([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,256,257,258,259,260,261,262,263,264,265,266,267,268,269,270,271,272,273,274,275,276,277,278,279,280,281,282,283,284,285,286,287,288,289,290,291,292,293,294,295,296,297,298,299,300], 1891);

# Fails thanks to unknown data type
my $fail = Data::Plist::BinaryWriter->new( serialize => 0);
my $ret = eval{$fail->write([ random => 0 ])};
ok (not ($ret), "Binary plist didn't write.");
like ($@, qr/Can't/i, "Threw an error.");

sub round_trip {
    my $write = Data::Plist::BinaryWriter->new;
    $in = trip($write, @_);
    is_deeply( $in->data, $_[0], "Read back " . $_[0] );
}

sub preserialized_trip {
    my $write = Data::Plist::BinaryWriter->new( serialize => 0 );
    $in = trip($write, @_);
    is_deeply( $in->raw_data, $_[0], "Read back " . $_[0] );
}

sub trip {
    my $read = Data::Plist::BinaryReader->new;
    my ( $write, $input, $expected_size ) = @_;
    ok( $write, "Created a binary writer" );
    isa_ok( $write, "Data::Plist::BinaryWriter" );
    $out = $write->write($input);
    ok( $out, "Created data structure" );
    like( $out, qr/^bplist00/, "Bplist begins with correct header" );
    is( "$@", '', "No errors thrown." );
    is( length($out), $expected_size,
        "Bplist is " . $expected_size . " bytes long." );
    $in = eval { $read->open_string($out) };
    ok( $in, "Read back bplist" );
    isa_ok( $in, "Data::Plist" );
    return $in;
}
