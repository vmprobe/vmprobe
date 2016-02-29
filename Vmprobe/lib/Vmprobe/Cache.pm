package Vmprobe::Cache;

use common::sense;

require XSLoader;
XSLoader::load;


our $locks = {};
our $snapshots = {};


1;
