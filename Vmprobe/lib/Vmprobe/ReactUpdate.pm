package Vmprobe::ReactUpdate;

use common::sense;


## A perl implementation of the update shipped with react, plus an $unset command, "correct" unshift ordering, and auto-vivification
## https://facebook.github.io/react/docs/update.html


sub update {
    my ($view, $update) = @_;

    die "update is not a hash ref" if ref($update) ne 'HASH';

    ## Process commands:

    if (exists $update->{'$set'}) {
        return $update->{'$set'};
    }

    if (exists $update->{'$unset'}) {
        $view = {} if !defined($view);
        die "view is not a hash ref in unset" if ref($view) ne 'HASH';
        my $new_view = { %$view };
        delete $new_view->{$update->{'$unset'}};
        return $new_view;
    }

    if (exists $update->{'$merge'}) {
        $view = {} if !defined($view);
        die "view is not a hash ref in merge" if ref($view) ne 'HASH';
        die "update is not a hash ref in merge" if ref($update->{'$merge'}) ne 'HASH';
        return { %$view, %{ $update->{'$merge'} } };
    }

    if (exists $update->{'$push'}) {
        $view = [] if !defined($view);
        die "view is not an array ref in push" if ref($view) ne 'ARRAY';
        return [ @$view, @{ $update->{'$push'} } ];
    }

    if (exists $update->{'$unshift'}) {
        $view = [] if !defined($view);
        die "view is not an array ref in unshift" if ref($view) ne 'ARRAY';
        return [ @{ $update->{'$unshift'} }, @$view ];
    }

    if (exists $update->{'$splice'}) {
        $view = [] if !defined($view);
        die "view is not an array ref in splice" if ref($view) ne 'ARRAY';
        die "update is not an array ref in splice" if ref($update->{'$splice'}) ne 'ARRAY';

        my $new_view = [ @$view ];

        foreach my $s (@{ $update->{'$splice'} }) {
            die "update element is not an array ref" if ref($s) ne 'ARRAY';
            splice(@$new_view, $s->[0], $s->[1], @{$s}[2 .. @$s - 1]);
        }

        return $new_view;
    }


    # Recurse to handle nested commands in $update:

    $view = {} if !defined($view);

    if (ref($view) eq 'HASH') {
        my $output = { %$view };

        foreach my $k (keys %$update) {
            $output->{$k} = update->($output->{$k}, $update->{$k});
        }

        return $output;
    } elsif (ref($view) eq 'ARRAY') {
        my $output = [ @$view ];

        foreach my $k (keys %$update) {
            die "non-numeric key in array update" if $k !~ /^\d+$/;
            $output->[$k] = update->($output->[$k], $update->{$k});
        }

        return $output;
    }

    die "view not an array or hash";
}


1;
