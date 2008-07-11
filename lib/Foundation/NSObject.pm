package Foundation::NSObject;

use strict;
use warnings;

sub init {
    my $self = shift;
}

sub replacement {
    my $self = shift;
    $self->init;
    return $self;
}

1;
