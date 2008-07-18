use Test::More no_plan => 1;

use strict;
use warnings;

use Data::Plist::BinaryReader;
use Data::Plist::BinaryWriter;

my $ret;

# Create the object
my $read = Data::Plist::BinaryReader->new;
ok( $read, "Created a binary reader" );
isa_ok( $read, "Data::Plist::BinaryReader" );

# Create writer
my $write = Data::Plist::BinaryWriter->new;
ok( $write, "Created a binary writer" );
isa_ok( $write, "Data::Plist::BinaryWriter" );

### Basic plist munging

# Magic header is magic
$ret = eval {$read->open_string("moose")};
ok( not($ret), "Not bplist doesn't load" );
like( "$@", qr/not a binary plist/i, "Threw an error" );

# No trailer
$ret = eval {$read->open_string("bplist00")};
ok( not($ret), "No trailer doesn't load" );
like( "$@", qr/trailer/i, "Threw an error" );

# Trailer overlaps with header; file is < 32 bytes long
$ret = eval {$read->open_string("bplist00" . ("!"x 20))};
ok( not($ret), "Trailer too short doesn't load" );
like( "$@", qr/trailer/i, "Threw an error" );

# Trailer overlaps with header; file is 32 bytes long
$ret = eval {$read->open_string("bplist00" . ("!"x 24))};
ok( not($ret), "Trailer too short doesn't load" );
like( "$@", qr/trailer/i, "Threw an error" );

# Slightly less overlap, but still some
$ret = eval {$read->open_string("bplist00" . ("!"x 28))};
ok( not($ret), "Trailer too short doesn't load" );
like( "$@", qr/trailer/i, "Threw an error" );

# Plist has no real data
$ret = eval {$read->open_string("bplist00" . pack("x6CC(x4N)3",1,1,0,0,8))};
ok( not($ret), "Plist with no contents is bogus" );
like( "$@", qr/top object/i, "Threw an error" );

# Smallest valid bplist!
$ret = eval {$read->open_string("bplist00" . pack("CCx6CC(x4N)3",0,8,1,1,1,0,9))};
ok( $ret, "Tiny plist is valid" );
isa_ok( $ret, "Data::Plist" );
is_deeply( $ret->raw_data => [ null => 0 ], "Has a null");


### Offset table

# Data overlap
$ret = eval {$read->open_string("bplist00" . pack("Cx6CC(x4N)3",8,1,1,1,0,8))};
ok( not($ret), "data overlaps with trailer");
like( "$@", qr/invalid address/i, "Threw an error" );

# More data overlap
$ret = eval {$read->open_string("bplist00" . pack("CCx6CC(x4N)3",0,9,1,1,1,0,9))};
ok( not($ret), "data overlaps with trailer");
like( "$@", qr/invalid address/i, "Threw an error" );

# Offset table doesn't need to be at the end
$ret = eval {$read->open_string("bplist00" . pack("CCx6CC(x4N)3",9,0,1,1,1,0,8))};
ok( $ret, "Tiny plist is valid" );
isa_ok( $ret, "Data::Plist" );
is_deeply( $ret->raw_data => [ null => 0 ], "Has a null");

# Offset table has too early address
$ret = eval {$read->open_string("bplist00" . pack("Cx6CC(x4N)3",0,1,1,1,0,8))};
ok( not($ret), "address too small");
like( "$@", qr/invalid address/i, "Threw an error" );

# Offset table has too late address
$ret = eval {$read->open_string("bplist00" . pack("Cx6CC(x4N)3",10,1,1,1,0,8))};
ok( not($ret), "address too small");
like( "$@", qr/invalid address/i, "Threw an error" );

# Wrong offset size horks
$ret = eval {$read->open_string("bplist00" . pack("Cnx6CC(x4N)3",0,8,1,1,1,0,9))};
ok( not($ret), "Wrong offset");
like( "$@", qr/invalid address/i, "Threw an error" );

# Two byte addresses do work
$ret = eval {$read->open_string("bplist00" . pack("Cnx6CC(x4N)3",0,8,2,1,1,0,9))};
ok( $ret, "Two byte addresses work" );
isa_ok( $ret, "Data::Plist" );
is_deeply( $ret->raw_data => [ null => 0 ], "Has a null");


### More complex testing

# Load from a file
$ret = $read->open_file("t/data/basic.binary.plist");
ok( $ret, "Got a value from open with a filename" );
isa_ok( $ret, "Data::Plist" );
ok( $ret->raw_data, "Has data inside" );

# Load from fh
my $fh;
open( $fh, "<", "t/data/basic.binary.plist");
$ret = $read->open_fh( $fh );
ok( $ret, "Opening from a fh worked" );
isa_ok( $ret, "Data::Plist" );
ok( $ret->raw_data, "Has data inside" );

# Load from string
my $str = do {local @ARGV = "t/data/basic.binary.plist"; local $/; <>};
ok( $str, "Read binary data in by hand" );
$ret = $read->open_string( $str );
ok( $ret, "Opening from a string worked" );
isa_ok( $ret, "Data::Plist" );
ok( $ret->raw_data, "Has data inside" );

# Test raw structure
is_deeply(
    $ret->raw_data,
    [   dict => {
            a => [
                array => [
                    [ integer => 1 ],
                    [ integer => 2 ],
                    [   dict => {
                            foo  => [ string => "bar" ],
                            baz  => [ string => "troz" ],
                            zort => [ string => '$null' ],
                        }
                    ]
                ]
            ]
        }
    ],
    "Raw structure matches",
);

# Data contains bplist
my $bplist = $write->write({});
my $in = $write->write({"test" => $bplist});
ok ($in, "Binary data written.");
$ret = $read->open_string($in);
ok ($ret, "Opening from string worked");
