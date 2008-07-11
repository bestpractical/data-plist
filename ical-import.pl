#!/usr/bin/perl
use strict;
use warnings;

use lib 'lib';
use YAML;
use Data::Plist;
use Data::Plist::BinaryReader;
use Email::MIME;
use File::Slurp;

for my $f (@ARGV) {
    my $content = read_file($f);
    unless ($content =~ /^bplist/) {
        my $mime = Email::MIME->new( $content );
        $content = ($mime->parts)[1]->body;
    }

    my $p = Data::Plist::BinaryReader->open_string($content);
    my $o = $p->object;
    print YAML::Dump($p->object);
}
