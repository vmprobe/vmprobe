package VmprobeModuleBuild;

use strict;

use parent 'Module::Build';

use List::Util;



sub ACTION_build {
    my $self = shift;

    system('cd ../libvmprobe/ && make -j 4') && die "failed to build libvmprobe";

    $self->SUPER::ACTION_build;

    install_version('blib/lib/Vmprobe.pm', git_describe('vmprobe'));
    install_version('blib/lib/Vmprobe/Daemon.pm', git_describe('vmprobed'));

    if (mtime('vmprobe') < List::Util::max(
                               mtime('../libvmprobe/libvmprobe.so'),
                               mtime('blib'),
                               mtime(__FILE__),
                           )) {
        bundle_vmprobe();
    }

    if (mtime('vmprobed') < List::Util::max(
                               mtime('../libvmprobe/libvmprobe.so'),
                               mtime('blib'),
                               mtime(__FILE__),
                           )) {
        bundle_vmprobe_daemon();
    }
}


sub ACTION_clean {
    my $self = shift;

    unlink('vmprobe');
    unlink('vmprobed');

    $self->SUPER::ACTION_build;
}


sub bundle_vmprobe {
    pp_wrapper(q{
        bin/vmprobe
        -l ../libvmprobe/libvmprobe.so

        -M Vmprobe::Cmd::
        -M Vmprobe::Probe::
        -M Net::OpenSSH::

        -o vmprobe
    });
}


sub bundle_vmprobe_daemon {
    pp_wrapper(q{
        bin/vmprobed
        -l ../libvmprobe/libvmprobe.so

        -M Net::OpenSSH::

        -o vmprobed
    });
}


sub pp_wrapper {
    my $args = shift;

    my $cmd = qq{
        $^X -Mblib `which pp`
        $args
    };

    $cmd =~ s/\s+/ /g;
    $cmd =~ s/^\s+//g;

    print "$cmd\n";
    system($cmd);
}




my $version_cache;

sub git_describe {
    my $dist = shift;

    return $version_cache->{$dist} if defined $version_cache->{$dist};

    $version_cache->{$dist} = `git describe --tags --match '$dist-*'`;
    chomp $version_cache->{$dist};

    $version_cache->{$dist} =~ s/^$dist-//;

    return $version_cache->{$dist};
}



sub install_version {
    my ($file, $version) = @_;

    my $contents;

    {
        open(my $fh, '<', $file) || die "couldn't open $file for reading: $!";
        local $/;
        $contents = <$fh>;
    }

    my $orig_contents = $contents;
    $contents =~ s{VERSION = '[^']*';}{VERSION = '$version';};

    if ($orig_contents ne $contents) {
        system("chmod u+w $file");
        open(my $fh, '>', $file) || die "couldn't open $file for writing: $!";
        print $fh $contents;
    }
}


sub mtime {
    my $filename = shift;

    return 0 if !-e $filename;

    return `find '$filename' -type f -printf '%T@\n' |sort -rn|head -1`;
}


1;
