package Foundation::NSDate;

use base qw/Foundation::NSObject DateTime/;

sub replacement {
    my $self = shift;
    my $dt = DateTime->from_epoch( epoch => $self->{"NS.time"} + 978307200 );
    bless $dt, (ref $self);
    return $dt;
}

sub serialize {
    my $self = shift;
    return { "NS.time" => $self->epoch - 978307200 };
}

1;


