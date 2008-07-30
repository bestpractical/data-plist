use Test::More no_plan => 1;

use strict;
use warnings;

use Data::Plist::BinaryReader;
use Data::Plist::BinaryWriter;
use Foundation::NSObject;
use YAML;

my $ret;
my $read = Data::Plist::BinaryReader->new;
my $p    = $read->open_file("t/data/todo.plist");
my $o    = $p->object;    # Should return a Foundation::LibraryTodo, which
                                        # isa Foundation::NSObject
isa_ok( $o, "Foundation::NSObject" );
my $s = Data::Plist::BinaryWriter->write($o);    # Returns a binary plist
ok( $s, "Write successful." );
my $r = $read->open_string($s);
ok( $r, "Second read successful" );
isa_ok( $r, "Data::Plist" );
