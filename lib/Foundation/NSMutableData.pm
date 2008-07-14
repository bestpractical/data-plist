package Foundation::NSMutableData;

use strict;
use warnings;

use base qw/Foundation::NSData/;

sub data {
    my $self = shift;
    return $self->{"NS.data"};
}

sub serialize_equiv {
    my $self = shift;
    return $self->SUPER::serialize_equiv unless ref $self->data;
    # XXX TODO: This should be BinaryWriter, but it hasn't been written yet
    return { "NS.data" => Data::Plist::XMLWriter->open_string($self->data) };
}

1;


