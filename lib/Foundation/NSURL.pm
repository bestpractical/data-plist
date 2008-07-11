package Foundation::NSURL;

use base qw/Foundation::NSObject URI::http/;

sub replacement {
    my $self = shift;
    my $uri = URI->new($self->{"NS.relative"}, "http");
    bless $uri, (ref $self);
    return $uri;
}

sub serialize {
    my $self = shift;
    return { "NS.relative" => $self->as_string };
}

1;
