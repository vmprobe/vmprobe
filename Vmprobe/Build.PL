use 5.010;

use strict;

use lib q(.);
use VmprobeModuleBuild;

my %module_build_args = (
  module_name => 'Vmprobe',
  dist_abstract => 'Vmprobe',
  dist_author => [ 'Doug Hoyte <doug@hcsw.org>' ],
  license => 'gpl3',

  script_files => [ 'bin/vmprobe', 'bin/vmprobed', ],

  build_requires => {
    'Module::Build' => '0.4214',
    'PAR::Packer' => '1.029',
  },
  configure_requires => {
    'Module::Build' => '0.4214',
    'Alien::LMDB' => 0,
  },
  requires => {
    ## Common
    'common::sense' => 0,
    'AnyEvent' => 0,
    'EV' => 0,
    'Getopt::Long' => 0,
    'Session::Token' => 0,
    'YAML' => 0,
    'JSON::XS' => 0,
    'Callback::Frame' => 0,
    'Guard' => 0,

    ## Vmprobe
    'Net::OpenSSH' => 0,
    'Term::ANSIColor' => 0,
    'Term::Size' => 0,
    'Text::Wrapper' => 0,
    'Sereal::Decoder' => 0,
    'Sereal::Encoder' => 0,

    ## Daemon
    'LMDB_File' => 0,
    'Plack' => 0,
    'Plack::Middleware::ContentLength' => 0,
    'Plack::Middleware::Deflater' => 0,
    'Regexp::Assemble' => 0,
    'Twiggy::Server' => 0,
    'Log::Defer' => 0,
    'Log::Dispatch::File::Rolling' => 0,
  },
  test_requires => {
  },

  extra_compiler_flags => ['-x', 'c++', '-std=c++11', '-I../libvmprobe'],
  extra_linker_flags => ['-L../libvmprobe', '-lstdc++', '-lvmprobe'],

  meta_merge => {
    resources => {
      homepage => 'https://github.com/vmprobe/vmprobe',
      bugtracker => 'https://github.com/vmprobe/vmprobe/issues',
      repository => 'git://github.com/vmprobe/vmprobe.git',
    },
  },
);



my $build = VmprobeModuleBuild->new(%module_build_args);

$build->create_build_script;
