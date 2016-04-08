package Vmprobe::Raw::getfile;

use common::sense;


sub run {
    my $params = shift;

    my $fh;

    if (!open($fh, '<:raw', $params->{path})) {
        return { error => "open: $!" };
    }

    my $contents;

    {
        local $/;
        $contents = <$fh>;
    }

    return { contents => $contents };
}

1;
