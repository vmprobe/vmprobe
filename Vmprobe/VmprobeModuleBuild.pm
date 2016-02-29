package VmprobeModuleBuild;

use strict;

use parent 'Module::Build';

sub ACTION_build {
  my $self = shift;

  system('cd libvmprobe/ && make -j 4') && die "failed to build libvmprobe";

  if (!$self->in_repo_dev_mode() && !-d 'blib/lib/auto/share/dist/Vmprobe/') {
    system('mkdir -p blib/lib/auto/share/dist/Vmprobe/');

    system('cp libvmprobe/libvmprobe.so blib/lib/auto/share/dist/Vmprobe/') && die "failed to copy libvmprobe.so into share dir";
  }

  $self->SUPER::ACTION_build;
}



sub in_repo_dev_mode {
  require("lib/Vmprobe.pm");
  return ($Vmprobe::VERSION eq 'REPO_DEV_MODE');
}


1;
