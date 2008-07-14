package Foundation::NSObject;

use strict;
use warnings;
use Class::ISA;
use UNIVERSAL::isa;
use Scalar::Util qw//;

sub init {
    my $self = shift;
}

sub replacement {
    my $self = shift;
    $self->init;
    return $self;
}

sub serialize_class {
    my $self = shift;
    $self = ref $self if ref $self;

    my $short = $self;
    $short =~ s/^Foundation:://;
    return [
        UID => [
            dict => {
                '$classes' => [
                    array => [
                        map { s/^Foundation:://; [ string => $_ ] }
                            grep { $_->isa("Foundation::NSObject") }
                            Class::ISA::self_and_super_path($self)
                    ]
                ],
                '$classname' => [ string => $short ],
            }
        ]
    ];
}

sub serialize_equiv {
    my $self = shift;
    return { %{ $self } };
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
    my %dict;
    $dict{'$class'} = $self->serialize_class;
    my $equiv = $self->serialize_equiv;
    for my $key (keys %{$equiv}) {
        my $value = $self->serialize_value($equiv->{$key});
        if ($value->[0] =~ /^(data|integer|real|true|false)$/) {
            $dict{$key} = $value;
        } else {
            $dict{$key} = [ UID => $value ];
        }
    }
    return [ dict => \%dict ];
}

1;
