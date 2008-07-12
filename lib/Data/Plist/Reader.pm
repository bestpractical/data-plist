package Data::Plist::Reader;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {} => $class;
}

sub open_string {
    my $self = shift;
    my ($content) = @_;

    my $fh;
    open( $fh, "<", \$content );
    return $self->open_fh($fh);
}

sub open_file {
    my $self = shift;
    my ($filename) = @_;

    my $fh;
    open( $fh, "<", $filename ) or die "can't open $filename for conversion";
    binmode($fh);
    return $self->open_fh($fh);
}

sub open_fh {
    my $self = shift;

    die "Unimplemented!";
}

1;
