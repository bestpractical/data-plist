package Data::Plist::XMLWriter;

use strict;
use warnings;

use base qw/Data::Plist::Writer/;
use XML::Writer;
use MIME::Base64 qw//;

sub write_fh {
    my $self = shift;
    $self = $self->new() unless ref $self;

    my ( $fh, $object ) = @_;
    local $self->{x}
        = XML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 8 );
    $self->{x}->xmlDecl( "UTF-8" );
    $self->{x}->doctype(
        "plist",
        "-//Apple//DTD PLIST 1.0//EN",
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd"
    );
    $self->{x}->startTag( plist => version => "1.0" );
    $object = $self->serialize($object) if ($self->{serialize});
    $self->xml_write( $object );
    $self->{x}->endTag("plist");
    $self->{x}->end();

    return 1;
}

sub xml_write {
    my $self = shift;
    my $data = shift;

    if ( $data->[0] =~ /^(true|false)$/ ) {
        $self->{x}->emptyTag( $data->[0] );
    } elsif ( $data->[0] =~ /^(integer|real|date|string|ustring)$/ ) {
        $self->{x}->dataElement( $data->[0], $data->[1] );
    } elsif ( $data->[0] eq "UID" ) {
        # UIDs are only hackishly supported in the XML version.
        # Apple's plutil converts them as follows:
        $self->{x}->startTag("dict");
        $self->{x}->dataElement( "key",     'CF$UID' );
        $self->{x}->dataElement( "integer", $data->[1] );
        $self->{x}->endTag("dict");
    } elsif ( $data->[0] eq "data" ) {
        $self->{x}->dataElement( "data",
            MIME::Base64::encode_base64( $data->[1] ) );
    } elsif ( $data->[0] eq "dict" ) {
        $self->{x}->startTag("dict");
        for my $k ( keys %{ $data->[1] } ) {
            $self->{x}->dataElement( "key", $k );
            $self->xml_write( $data->[1]{$k} );
        }
        $self->{x}->endTag("dict");
    } elsif ( $data->[0] eq "array" ) {
        $self->{x}->startTag("array");
        $self->xml_write($_) for @{ $data->[1] };
        $self->{x}->endTag("array");
    } else {
        $self->{x}->comment( $data->[0] );
    }
}

1;
