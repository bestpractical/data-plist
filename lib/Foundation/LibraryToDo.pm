package Foundation::LibraryToDo;

use base qw/Foundation::ToDo Class::Accessor/;

my %mapping = (
    alarms       => [ "ToDo Alarms"         => undef ],
    cal_id       => [ "ToDo Calendar ID"    => "string" ],
    calendar     => [ "ToDo Calendar Title" => "string" ],
    complete     => [ "ToDo Completed"      => "bool" ],
    completed_at => [ "ToDo Date Completed" => undef ],
    created      => [ "ToDo Date Created"   => undef ],
    due          => [ "ToDo Due Date"       => undef ],
    notes        => [ "ToDo Notes"          => "string" ],
    priority     => [ "ToDo Priority"       => "int" ],
    title        => [ "ToDo Title"          => "string" ],
    url          => [ "ToDo URL"            => undef ],
    id           => [ "ToDo iCal ID"        => "string" ],
    keys_digest  => [ "ToDo Keys Digest"    => undef ],
);

my %lookup = (map {($mapping{$_}[0] => $_)} keys %mapping);


sub init {
    my $self = shift;

    __PACKAGE__->mk_accessors(grep {not $self->can($_)} keys %mapping);
    $self->{$lookup{$_}} = delete $self->{$_} for grep {exists $lookup{$_}} keys %{$self};

    $self->due(undef) unless delete $self->{"ToDo Due Date Enabled"};
    $self->priority(undef) unless delete $self->{"ToDo Priority Enabled"};
}

sub serialize {
    my $self = shift;
    my $ret = {};

    for my $k (keys %mapping) {
        $ret->{$keys}
    }

    return ["dict", $ret];
}

1;


