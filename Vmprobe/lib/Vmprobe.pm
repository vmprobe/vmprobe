package Vmprobe;

our $VERSION = 'PLACEHOLDER';

1;



__END__


=encoding utf-8

=head1 NAME

Vmprobe - The control panel for your cloud's memory

=head1 SYNOPSIS

    $ vmprobe --help

=head1 DESCRIPTION

vmprobe is a utility for developers and system administrators for analyzing and optimizing the filesystem cache of a cluster or cloud. You can learn more about it at our website: L<vmprobe.com|https://vmprobe.com>.

This software is very much in beta. There are some known bugs and a lot of features we still plan on adding.

This module installs the C<vmprobe> binary in your path and most interaction is done through this binary, including starting the web GUI:

    $ vmprobe web


=head1 SEE ALSO

L<Official vmprobe website|https://vmprobe.com>

L<The vmprobe github repo|https://github.com/vmprobe/vmprobe>

Bug reports? Feature requests? General requests? L<File a github issue!|https://github.com/vmprobe/vmprobe/issues/new>


=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2016 Doug Hoyte and Vmprobe Inc.

This module is licensed under the GNU GPL 3.

=cut
