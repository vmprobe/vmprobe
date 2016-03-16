package Vmprobe::Cache;

use common::sense;

require Vmprobe;
Vmprobe::load_libvmprobe();

require XSLoader;
XSLoader::load;


our $locks = {};
our $snapshots = {};


1;
