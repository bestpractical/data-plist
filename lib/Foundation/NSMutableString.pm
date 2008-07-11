package Foundation::NSMutableString;

use strict;
use warnings;

use base qw/Foundation::NSString/;

sub replacement {
    my $self = shift;
    return $self->{"NS.string"};
}

1;
