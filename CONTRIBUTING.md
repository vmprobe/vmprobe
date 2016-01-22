## Installing pre-built vmprobe

Many platforms have pre-built packages for vmprobe and this is the
recommended way to use it if you don't plan to modify vmprobe itself:

Soon we will have pre-built packages for popular platforms available on
our [install page](https://vmprobe.com/install), but for now should
either install from source (read on) or from CPAN, for example with [cpanminus](https://metacpan.org/pod/App::cpanminus):

    cpanm Vmprobe --sudo

The rest of this document describes how to build vmprobe from source
code in order to get the latest unreleased features and bug fixes, or
to add new features of your own.


## Developing

If you would like to modify vmprobe's source code, you should check
out our git repository from github:

[https://github.com/vmprobe/vmprobe](https://github.com/vmprobe/vmprobe)

After the repo is checked out, you can run the top-level build.pl script
which will print more information:

    ./build.pl

The fastest way to get everything compiled is to run the `quick-dev`
or `quick-dev-no-root` commands:

    ./build.pl quick-dev

or

    ./build.pl quick-dev-no-root

Both commands will install perl (CPAN) and javascript (NPM) dependencies
as well as compiling libvmprobe and the Vmprobe perl distribution.
The quick-dev-no-root command will install the perl dependencies in your
home directory (and therefore doesn't need you to sudo) but you will need
to setup your perl environment with local::lib. More information will be
printed by cpanm if this is not setup properly.

## Contributing

If you would like to contribute to vmprobe, first of all: thank you!

Please use our github bug tracker for any bugs, feature requests, or
even simple questions:

[https://github.com/vmprobe/vmprobe/issues](https://github.com/vmprobe/vmprobe/issues)

Pull-requests are also very much appreciated:

[https://github.com/vmprobe/vmprobe/pulls](https://github.com/vmprobe/vmprobe/pulls)

Please also stop by our IRC channel (#vmprobe on EFNet) if you feel like chatting.

### Developing Vmprobe (perl)

In the `Vmprobe` directory, you should use standard [Module::Build](https://metacpan.org/pod/Module::Build)
install commands:

    perl Build.PL
    ./Build
    ./Build test

Note that the `./Build` command compiles things and stores them in the `blib/`
directory, so if you modify and `.pm` or `.xs` files you will need to
re-run `./Build` for your changes to take effect.

### Developing libvmprobe (C++)

In the `libvmprobe/` directory you should simply be able to run

    make -j 4

and it will re-build the necessary files.

You will need a compiler capable of compiling C++11 as well as GNU make.
On ubuntu you may need to run something like the following:

    sudo apt-get install build-essential g++

The perl module dynamically links in the `libvmprobe.so` file from the
`libvmprobe/` directory (via a `Vmprobe/libvmprobe` symlink) so you
don't need to re-build the perl module after recompiling the C++ code.

### Developing web (javascript+react)

In the `web` directory there is a `dev-server.js` file that is able to
run the [react hot-loader](https://gaearon.github.io/react-hot-loader/).
However, you don't need to run this manually. When you run vmprobe's
`web` command:

    ./Vmprobe/bin/vmprobe web

then a hot-loader process will be started in the background. When you
change and `.js` files then the changes should immediately appear in
your browser. You should only need to reload the browser if things get
in an inconsistent state (rare but sometimes happens).


## License and Copyright

vmprobe is (C) 2016 by Doug Hoyte and Vmprobe Inc.

It is distributed under the [GNU GPL version 3](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.

Please see the `COPYING` file in this directory for more details.
