package Data::Plist::Writer;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {} => $class;
}

sub write {
    my $self = shift;
    my $object = pop;
    my $to = shift;

    if (not $to) {
        my $content;
        my $fh;
        open( $fh, ">", \$content );
        $self->write_fh($fh, $object) or return;
        return $content;
    } elsif (ref $to) {
        $self->write_fh($to, $object)
    } else {
        my $fh;
        open( $fh, ">", $to ) or die "Can't open $to for writing: $!";
        $self->write_fh($fh, $object) or return;
    }
    return;
}

sub fold_uids {
    my $self = shift;
    my $data = shift;

    if ($data->[0] eq "UID") {
        require Digest::MD5;
        my $digest = Digest::MD5::md5_hex(YAML::Dump($data->[1]));
        if (exists $self->{objcache}{$digest}) {
            return [ UID => $self->{objcache}{$digest} ];
        }
        push @{$self->{objects}}, $self->fold_uids($data->[1]);
        $self->{objcache}{$digest} = @{$self->{objects}} - 1;
        return [ UID => @{$self->{objects}} - 1 ];
    } elsif ($data->[0] eq "array") {
        return ["array", [map {$self->fold_uids($_)} @{$data->[1]}]];
    } elsif ($data->[0] eq "dict") {
        my %dict = %{$data->[1]};
        $dict{$_} = $self->fold_uids($dict{$_}) for keys %dict;
        return ["dict", \%dict];
    } else {
        return $data;
    }
}

sub serialize {
    my $self = shift;
    my $object = shift;

    $object = $object->serialize if ref($object) ne "ARRAY" and $object->can("serialize");

    local $self->{objects}  = [];
    local $self->{objcache} = {};
    my $top = $self->fold_uids( [ dict => { root => [ UID => $object ] } ] );

    return [
        dict => {
            '$archiver' => [ string  => "NSKeyedArchiver" ],
            '$version'  => [ integer => 100_000 ],
            '$top'      => $top,
            '$objects'  => [ array   => $self->{objects} ],
        },
    ];
}

1;
