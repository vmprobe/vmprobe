package VmprobeModuleBuild;

use strict;

use parent 'Module::Build';

use List::Util;



sub ACTION_build {
    my $self = shift;

    system('cd ../libvmprobe/ && make -j 4') && die "failed to build libvmprobe";

    $self->SUPER::ACTION_build;

    install_version('blib/lib/Vmprobe.pm', git_describe('vmprobe'));
}

sub ACTION_clean {
    my $self = shift;

    unlink('vmprobe');

    $self->SUPER::ACTION_clean;

    system("rm -rf _bundle");
}




sub ACTION_bundle {
    my $self = shift;

    $self->ACTION_build;

    system("rm -rf _bundle");
    mkdir("_bundle") || die "couldn't mkdir: $!";



    require ExtUtils::Embed;

    my $ccopts = ExtUtils::Embed::ccopts();
    my $ldopts = ExtUtils::Embed::ldopts();
    chomp $ccopts;
    chomp $ldopts;

    my $cmd = "cc -o vmprobe main.c $ccopts -Wl,-rpath -Wl,/usr/lib/vmprobe/ $ldopts";
    sys($cmd);

    sys("cp bin/vmprobe-bundled _bundle/main.pl");



    my $ldd_line = `ldd ./vmprobe | grep libperl.so`;
    $ldd_line =~ /^\s*(libperl\S+)/ || die "couldn't parse ldd";
    my $lib_to_use = $1;

    require DynaLoader;

    my $libperl = DynaLoader::dl_findfile($lib_to_use);
    sys("cp $libperl _bundle/");



    build_par();
    sys("cd _bundle/ ; unzip -q ../vmprobe.par");
    unlink("vmprobe.par");
    sys("chmod -R u+w _bundle");


    sys("mv _bundle/shlib/*/*.so* _bundle/");
    sys("rm -rf _bundle/shlib/ _bundle/MANIFEST _bundle/META.yml _bundle/script");
    sys("chmod a-x _bundle/*.so*");
    sys("strip _bundle/libvmprobe.so");
    sys("strip _bundle/liblmdb.so");

    sys("rm -rf _bundle/lib/Tk/ _bundle/lib/Tk.pm _bundle/lib/auto/Tk/");
}


sub build_par {
    require Alien::LMDB;

    my $liblmdb_path = Alien::LMDB->new->dist_dir() . "/lib/liblmdb.so";

    pp_wrapper(qq{
        bin/vmprobe

        -l ../libvmprobe/libvmprobe.so
        -l $liblmdb_path

        -M Vmprobe::
        -M Vmprobe::Cmd::
        -M Vmprobe::Raw::

        ## Core modules not picked up by ScanDeps for some reason
        -M PerlIO -M attributes -M Tie::Hash::NamedCapture

        -F 'PodStrip=(?<!Grammars)\\.pm\$'

        ## Unicode support (not needed for now)
        ## -u -M _charnames -M utf8

        ## 3rd party modules

        -M Net::OpenSSH::
        -X TK::

        -B -p -o vmprobe.par
    });
}


sub pp_wrapper {
    my $args = shift;

    my $cmd = qq{
        PAR_VERBATIM=1
        $^X -Mblib `which pp`
        $args
    };

    $cmd =~ s/#[^\n]*\n//g;
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


sub sys {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd) && die;
}

1;
