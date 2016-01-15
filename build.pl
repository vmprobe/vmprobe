#!/usr/bin/env perl

use strict;


my $cmd_specs = [
  {
    cmd => 'quick-dev',
    doc => q{Get ready for development on vmprobe! (Please be patient...)
             * Installs CPAN dependencies globally (requires sudo)
             * Installs npm dependencies locally
             * Builds the Vmprobe perl mode in "repo dev mode"
           },
    run => sub {
      install_cpan_deps_global();
      install_npm_deps();
      build_perl_dev_mode();
    },
  },
  {
    cmd => 'quick-dev-no-root',
    doc => q{Same as quick-dev, except it installs CPAN deps locally (no root required).
             Since perl modules are installed in your home directory, you must set up local::lib.
             Further instructions will be printed by cpanm if this is not setup properly.
            },
    run => sub {
      install_cpan_deps_local();
      install_npm_deps();
      build_perl_dev_mode();
    },
  },
  {
    cmd => 'cpan',
    doc => q{Create a distribution ready for CPAN in the cpan-dist-dir/ directory},
    run => sub {
      prepare_perl_dir_for_cpan();
      clean_libvmprobe();
      build_web_resources();

      sys('rm -rf cpan-dist-dir/');
      sys('mkdir cpan-dist-dir');
      sys('cp -L -R Vmprobe/ cpan-dist-dir/');
      sys('cp -R web/dist/ cpan-dist-dir/Vmprobe/webdist/');
      sys('cp COPYING cpan-dist-dir/Vmprobe/');

      install_version('cpan-dist-dir/Vmprobe/lib/Vmprobe.pm', get_vmprobe_version());
      install_version('cpan-dist-dir/Vmprobe/bin/vmprobe', get_vmprobe_version());

      sys('cd cpan-dist-dir/Vmprobe/ && perl Build.PL && perl Build manifest');
      sys('cd cpan-dist-dir/Vmprobe/ && perl Build dist');
    },
  },
  {
    cmd => 'version',
    doc => q{Prints the version of vmprobe.},
    run => sub {
      print get_vmprobe_version(), "\n";
    },
  },
  {
    cmd => 'help',
    doc => q{Prints this help output.},
    run => sub {
      usage();
    },
  },
];


my $cmd = shift || usage('must supply a command as argument');
$cmd = 'help' if grep { $cmd eq $_ } qw{ -h --help -? };

foreach my $cmd_spec (@{ $cmd_specs }) {
  if ($cmd eq $cmd_spec->{cmd}) {
    $cmd_spec->{run}->();
    exit 0;
  }
}

usage("no such command: $cmd");




sub usage {
  my $reason = shift;

  print "vmprobe build system\n\n";

  print "Please run one of the following commands:\n\n";
  
  foreach my $cmd_spec (@{ $cmd_specs }) {
    my $doc = $cmd_spec->{doc};

    $doc =~ s/^\s+//;
    $doc =~ s/\n\s*/\n    /g;
    $doc =~ s/\s*\z//;

    print "  $0 $cmd_spec->{cmd}\n";
    print "    $doc\n";
    print "\n";
  }

  print "*** $reason ***\n" if defined $reason;

  exit 1;
}




sub install_cpan_deps_global {
    print "Installing CPAN deps to your system directories, please enter your sudo password when prompted...\n\n";
    check_cpanm_avail();
    sys('cpanm --installdeps ./Vmprobe/ --sudo');
}

sub install_cpan_deps_local {
    check_cpanm_avail();
    sys('cpanm --installdeps ./Vmprobe/');
}

sub check_cpanm_avail {
    if (!`which cpanm`) {
        print "'cpanm' is not in your path... Please install cpanminus:\n\n";

        my @methods;

        if (`which apt-get`) {
            push @methods, "sudo apt-get install cpanminus";
        }

        if (`which yum`) {
            push @methods, "sudo yum install perl-App-cpanminus";
        }

        if (`which cpan`) {
            push @methods, "sudo cpan App::cpanminus";
        }

        push @methods, 'curl -L https://cpanmin.us | perl - --sudo App::cpanminus';

        print join("\n\nOR\n\n", @methods), "\n\n";
        exit 1;
    }
}

sub install_npm_deps {
    sys('cd web && npm install');
}

sub build_perl_dev_mode {
    sys('cd Vmprobe/ && perl Build.PL && perl Build');

    print <<'END';

===========================================================================

vmprobe is ready for development!

You can run the command-line utility like so:

./Vmprobe/bin/vmprobe

Start up the web-server (including the hot-load react development server):

./Vmprobe/bin/vmprobe web

END
}

sub build_libvmprobe {
    sys('cd libvmprobe/ && make -j 4');
}

sub clean_libvmprobe {
    sys('cd libvmprobe/ && make clean');

    die "untracked files in libvmprobe/ directory"
        if `cd libvmprobe/ && git clean -nxd .`;
}

sub prepare_perl_dir_for_cpan {
    sys('cd Vmprobe/ && perl Build.PL');
    sys('cd Vmprobe/ && perl Build');
    sys('cd Vmprobe/ && perl Build test');
    sys('cd Vmprobe/ && perl Build realclean');

    die "untracked files in Vmprobe/ perl directory"
        if `cd Vmprobe/ && git clean -nxd .`;
}

sub build_web_resources {
    if (!-e 'web/node_modules/') {
        die "no web/node_modules/ (forgot to install npm deps?)";
    }

    sys('rm -rf web/dist/');
    sys('cd web && npm run dist');
    sys('cp web/index.html web/dist/');
}



sub sys {
    my $command = shift;

    print "SYS: $command\n";
    system($command) && die;
}



my $vmprobe_version;

sub get_vmprobe_version {
  return $vmprobe_version if defined $vmprobe_version;

  $vmprobe_version = `git describe --tags`;
  chomp $vmprobe_version;

  return $vmprobe_version;
}


sub install_version {
    my ($file, $version) = @_;

    my $contents;

    {
        open(my $fh, '<', $file) || die "couldn't open $file for reading: $!";
        local $/;
        $contents = <$fh>;
    }

    $contents =~ s{VERSION = 'REPO_DEV_MODE';}{VERSION = '$version';};

    open(my $fh, '>', $file) || die "couldn't open $file for writing: $!";
    print $fh $contents;
}
