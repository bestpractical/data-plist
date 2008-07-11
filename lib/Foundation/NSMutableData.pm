package Foundation::NSMutableData;

use base qw/Foundation::NSData/;

sub data {
    my $self = shift;
    return $self->{"NS.data"};
}

sub serialize {
}

1;


