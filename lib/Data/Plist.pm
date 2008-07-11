package Data::Plist;

use strict;
use warnings;

use Encode qw(decode encode);
use Fcntl qw(:seek);
use DateTime;
use POSIX ();
use Math::BigInt;
use MIME::Base64;
use UNIVERSAL::require;

use vars qw/$VERSION/;
$VERSION = "1.5";

sub new {
    my $class = shift;
    return bless { uids => undef, data => undef, @_ } => $class;
}

sub collapse {
    my $self = shift;
    my ($data) = @_;

    unless (ref $data eq "ARRAY") {
        warn "Got $data?";
        return "???";
    }

    if ($data->[0] eq "array") {
        return [ map $self->collapse($_), @{$data->[1]} ];
    } elsif ($data->[0] eq "dict") {
        my %dict = %{$data->[1]};
        $dict{$_} = $self->collapse($dict{$_}) for keys %dict;
        return \%dict;
    } elsif ($data->[0] eq "string") {
        return $data->[1] eq '$null' ? undef : $data->[1];
    } elsif ($data->[0] eq "date") {
        return DateTime->new( epoch => $data->[1] + 978307200);
    } elsif ($data->[0] eq "UID" and ref $data->[1]) {
        return $self->collapse($data->[1]);
    } else {
        return $data->[1];
    }

    return $data;
}

sub raw_data {
    my $self = shift;
    return $self->{data};
}

sub data {
    my $self = shift;
    return $self->collapse($self->raw_data);
}

sub is_archive {
    my $self = shift;
    my $data = $self->raw_data;
    return unless $data->[0] eq "dict";

    return unless exists $data->[1]{'$archiver'};
    return unless $data->[1]{'$archiver'}[0] eq "string";
    return unless $data->[1]{'$archiver'}[1] eq "NSKeyedArchiver";

    return unless exists $data->[1]{'$objects'};
    return unless $data->[1]{'$objects'}[0] eq "array";

    return unless exists $data->[1]{'$top'};

    return unless exists $data->[1]{'$version'};
    return unless $data->[1]{'$version'}[0] eq "int";
    return unless $data->[1]{'$version'}[1] eq "100000";

    return 1;
}

sub unref {
    my $self = shift;
    my $p = shift;
    if ($p->[0] eq "UID") {
        return ["UID", $self->unref( $self->raw_data->[1]{'$objects'}[1][ $p->[1] ] )];
    } elsif ($p->[0] eq "array") {
        return ["array", [map {$self->unref($_)} @{$p->[1]}]]
    } elsif ($p->[0] eq "dict") {
        my %dict = %{$p->[1]};
        $dict{$_} = $self->unref($dict{$_}) for keys %dict;
        return ["dict", \%dict];
    } elsif ($p->[0] eq "data" and ref $p->[1] and $p->[1]->isa("Data::Plist")) {
        return $p->[1]->raw_object;
    } else {
        return $p;
    }
}

sub reify {
    my $self = shift;
    my $data = shift;

    return $data unless ref $data;
    if (ref $data eq "HASH") {
        my $hash = { %{$data} };
        my $class = delete $hash->{'$class'};
        $hash->{$_} = $self->reify($hash->{$_}) for keys %{$hash};
        if ($class and ref $class and ref $class eq "HASH" and $class->{'$classname'}) {
            my $classname = "Foundation::" . $class->{'$classname'};
            if (not $classname->require) {
                warn "Can't require $classname: $@\n";
            } elsif (not $classname->isa("Foundation::NSObject")) {
                warn "$classname isn't a Foundation::NSObject\n";
            } else {
                bless($hash, $classname);
                $hash = $hash->replacement;
            }
        }
        return $hash;
    } elsif (ref $data eq "ARRAY") {
        return [map $self->reify($_), @{$data}];
    } else {
        return $data;
    }
}

sub raw_object {
    my $self = shift;
    return unless $self->is_archive;
    return $self->unref($self->raw_data->[1]{'$top'}[1]{root});
}

sub object {
    my $self = shift;
    return unless $self->is_archive;
    return $self->reify($self->collapse($self->raw_object));
}

1;
