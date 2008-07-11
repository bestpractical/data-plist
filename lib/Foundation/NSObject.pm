package Foundation::NSObject;

sub init {
    my $self = shift;
}

sub replacement {
    my $self = shift;
    $self->init;
    return $self;
}

1;
