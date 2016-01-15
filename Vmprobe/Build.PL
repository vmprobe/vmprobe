use strict;

use lib q(.);
use VmprobeModuleBuild;

my %module_build_args = (
  module_name => 'Vmprobe',
  dist_abstract => 'Vmprobe',
  dist_author => [ 'Doug Hoyte <doug@hcsw.org>' ],
  license => 'gpl3',

  script_files => [ 'bin/vmprobe' ],

  build_requires => {
    'Module::Build' => '0.4214'
  },
  configure_requires => {
    'Module::Build' => '0.4214'
  },
  requires => {
    'common::sense' => 0,
    'Net::OpenSSH' => 0,
    'Term::ANSIColor' => 0,
    'Term::Size' => 0,
    'Text::Wrapper' => 0,
    'AnyEvent' => 0,
    'Getopt::Long' => 0,
    'JSON::XS' => 0,
    'List::MoreUtils' => 0,
    'Plack' => 0,
    'Plack::App::Proxy' => 0,
    'Plack::Middleware::ContentLength' => 0,
    'Plack::Middleware::CrossOrigin' => 0,
    'Plack::Middleware::Deflater' => 0,
    'Plack::Middleware::Static' => 0,
    'Plack::Middleware::Rewrite' => 0,
    'Sereal::Decoder' => 0,
    'Sereal::Encoder' => 0,
    'Session::Token' => 0,
    'Twiggy::Server' => 0,
    'YAML' => 0,
    'File::ShareDir' => 0,
    'Callback::Frame' => 0,
    'Guard' => 0,
  },
  test_requires => {
  },

  extra_compiler_flags => ['-x', 'c++', '-std=c++11', '-Ilibvmprobe'],
  extra_linker_flags => ['-Llibvmprobe', '-lstdc++', '-lvmprobe'],
);



my $build = VmprobeModuleBuild->new(%module_build_args);

$build->create_build_script;
