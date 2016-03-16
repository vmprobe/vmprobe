package Vmprobe::Cache::Snapshot;

use common::sense;

require Vmprobe;
Vmprobe::load_libvmprobe();

require XSLoader;
XSLoader::load;

1;
