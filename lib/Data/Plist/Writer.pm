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

sub serialize_value {
    my $self = shift;
    my ($value) = @_;
    if (not defined $value) {
        return [ string => '$null' ];
    } elsif ( ref $value ) {
        if ( ref $value eq "ARRAY" ) {
            return [
                array => [ map { $self->serialize_value($_) } @{$value} ] ];
        } elsif ( ref $value and ref $value eq "HASH" ) {
            my %hash = %{$value};
            $hash{$_} = $self->serialize_value( $hash{$_} ) for keys %hash;
            return [ dict => \%hash ];
        } elsif ($value->isa("Foundation::NSObject")) {
            return $value->serialize;
        } elsif ($value->isa("DateTime")) {
            return [ date => $value->epoch - 978307200 + $value->nanosecond / 1e9 ];
        } else {
            die "Can't serialize unknown ref @{[ref $value]}\n";
        }
    } elsif ( $value !~ /\D/ ) {
        return [ integer => $value ];
    } elsif ( Scalar::Util::looks_like_number($value) ) {
        return [ real => $value ];
    } elsif ( $value =~ /\0/ or $value =~ /<\?xml/) {
        # XXX TODO: The /<\?xml/ is a hack to get it labelled DATA
        # until we use BinaryWriter to write nested plists
        return [ data => $value ];
    } else {
        return [ string => $value ];
    }
}

sub serialize {
    my $self = shift;
    my $object = shift;

    return $self->serialize_value($object)
      if ref($object) =~ /ARRAY|HASH/ or not $object->can("serialize");

    $object = $object->serialize;

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
