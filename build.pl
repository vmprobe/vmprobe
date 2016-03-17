#!/usr/bin/env perl

use strict;

use Cwd;


my $cmd_specs = [
  {
    cmd => 'quick-dev',
    doc => q{Get ready for development on vmprobe! (Please be patient...)
             * Installs CPAN dependencies globally (requires sudo)
             * Builds the Vmprobe perl mode in "repo dev mode"
           },
    run => sub {
      install_cpan_deps_global();
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
    },
  },
  {
    cmd => 'build',
    doc => q{Builds packed binaries in the Vmprobe directory},
    run => sub {
      build_perl();
      welcome_msg();
    },
  },
  {
    cmd => 'dist',
    doc => q{Create packages for vmprobe},
    run => sub {
      build_perl_bundle();

      fpm({
        types => [qw/ deb rpm /],
        name => 'vmprobe',
        version => get_vmprobe_version('vmprobe'),
        files => {
          'Vmprobe/vmprobe' => '/usr/bin/vmprobe',
        },
        dirs => {
          'Vmprobe/_bundle/' => '/usr/local/lib/vmprobe',
        },
        description => 'System probing tool for virtual memory and more',
        changelog => 'Vmprobe/Changes',
      });
    },
  },
  {
    cmd => 'version',
    doc => q{Prints the version of vmprobe.},
    run => sub {
      print "vmprobe: " . get_vmprobe_version('vmprobe'), "\n";
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
    $cmd_spec->{run}->(@ARGV);
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

sub build_perl {
    sys('cd Vmprobe/ && perl Build.PL && perl Build');
}

sub build_perl_bundle {
    sys('cd Vmprobe/ && perl Build.PL && perl Build bundle');
}

sub welcome_msg {
    print <<'END';

===========================================================================

vmprobe is ready for development!

You can run it like so:

cd Vmprobe
perl -Mblib bin/vmprobe

END
}



sub fpm {
    my $args = shift;

    my $cwd = cwd();

    $args->{url} //= 'https://vmprobe.com';
    $args->{license} //= 'GPL version 3';
    $args->{maintainer} //= 'Vmprobe Team <support@vmprobe.com>';

    die "need to install fpm ( https://github.com/jordansissel/fpm )"
        if !`which fpm`;

    require File::Temp;
    my $tmp = File::Temp::tempdir(CLEANUP => 1);

    sys("mkdir -p dist");

    foreach my $type (@{ $args->{types} }) {
        foreach my $src (keys %{ $args->{files} }) {
            my $dest = "$tmp/$args->{files}->{$src}";

            my $dest_path = $dest;
            $dest_path =~ s{[^/]+\z}{};

            sys("mkdir -p $dest_path") if !-d $dest_path;
            sys("cp $src $dest");
        }

        foreach my $src (keys %{ $args->{dirs} }) {
            my $dest = "$tmp/$args->{dirs}->{$src}";

            sys("mkdir -p $dest");
            sys("cp -r $src/* $dest");
        }


        my $changelog = '';

        if (exists $args->{postinst}) {
            my $changelog_path = "$cwd/$args->{changelog}";

            if ($type eq 'deb') {
                $changelog = qq{ --deb-changelog "$changelog_path" };
            } elsif ($type eq 'rpm') {
                ## FIXME: fpm breaks?
                #$changelog = qq{ --rpm-changelog "$changelog_path" };
            } else {
                die "unknown type: $type";
            }
        }


        my $postinst = '';

        if (exists $args->{postinst}) {
            $postinst = qq{ --after-install "$cwd/$args->{postinst}" };
        }


        my $cmd = qq{
            cd dist ; fpm
              -n "$args->{name}"
              -s dir -t $type
              -v $args->{version}

              --url "$args->{url}"
              --description "$args->{description}"
              --license "$args->{license}"
              --maintainer "$args->{maintainer}"
              --vendor ''

              $changelog
              $postinst

              -f -C $tmp .
        };

        $cmd =~ s/\s+/ /g;
        $cmd =~ s/^\s*//;

        sys($cmd);
    }
}


sub sys {
    my $command = shift;

    print "SYS: $command\n";
    system($command) && die;
}



my $version_cache;

sub get_vmprobe_version {
    my $dist = shift;

    return $version_cache->{$dist} if defined $version_cache->{$dist};

    $version_cache->{$dist} = `git describe --tags --match '$dist-*'`;
    chomp $version_cache->{$dist};

    $version_cache->{$dist} =~ s/^$dist-//;

    return $version_cache->{$dist};
}
