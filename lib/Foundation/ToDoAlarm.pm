package Foundation::ToDoAlarm;

use strict;
use warnings;

use base qw/Foundation::NSObject/;

sub serialize {
    my $self = shift;
    my $ret  = $self->SUPER::serialize;
    $ret->{"ToDo Alarm Enabled"} = $ret->{"ToDo Alarm Enabled"}[1] ? [ true => 1 ] : [ false => 0 ];
    return $ret;
}

1;
