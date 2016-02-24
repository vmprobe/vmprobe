package Vmprobe::Resource::MemInfo;

use common::sense;

use parent 'Vmprobe::Resource::Base::AllRemotes';



sub poll_remote {
    my ($self, $remote) = @_;

    return {
        probe_name => 'getfile',
        args => { path => '/proc/meminfo', },
        on_result => sub {
            my ($result) = @_;

            my $remote_pos = $self->get_remote_position($remote);

            my $mem_info = parse_proc_meminfo($result->{contents});

            $self->update({
                remotes => {
                    $remote_pos => {
                        '$merge' => {
                            mem_info => $mem_info,
                        },
                    },
                },
            });
        },
    };
}




sub parse_proc_meminfo {
    my $contents = shift;

    my $output;

    for my $line (split /\n/, $contents) {
        if ($line =~ /^([^:]+):\s*(\d+)\s*(kB|)/) {
            my $val = $2;
            $val /= 4 if $3; ## turn kB into pages
            $output->{$1} = $val;
        }
    }

    return $output;
}




1;
