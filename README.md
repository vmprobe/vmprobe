[![vmprobe logo](https://vmprobe.github.io/vmprobe/logo.svg)](https://vmprobe.com)

# vmprobe

[official website](https://vmprobe.com)

## Introduction

vmprobe is a utility for managing the virtual memory of your cloud, cluster, or servers. It is based on [vmtouch](https://hoytech.com/vmtouch/) technology but it adds many new capabilities.

For a more comprehensive introduction, please see our [official documentation](https://vmprobe.com/intro).


## Installing

The [vmprobe install page](https://vmprobe.com/install) has pre-built linux packages which are the recommended way to deploy vmprobe. However, if you plan on developing vmprobe yourself, you will need to compile from source.


## Compiling from source

There are some compile-time dependencies needed. On Ubuntu you should be able to get them with this command:

    sudo apt-get install build-essential g++ libperl-dev cpanminus

Next you need to download the perl-time dependencies from CPAN. There is a script in this repo that you can run to do that:

    ./build.pl quick-dev

You will be prompted for your password so that cpanminus can install the packages globally on your system.

Finally, you should be able to build the `vmprobe` and `vmprobed` binaries with this command:

    ./build.pl build

If you run into any trouble, please [create a github issue](https://github.com/vmprobe/vmprobe/issues/new).


## Contributing

If you would like to contribute to vmprobe, thank you! Pull requests are very welcome.

Please [create a github issue](https://github.com/vmprobe/vmprobe/issues/new) with any bug report, feature request, or even general question relating to vmprobe.



## License

vmprobe is (C) 2016 by Doug Hoyte and Vmprobe Inc.

It is distributed under the [GNU GPL version 3](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.

Please see the COPYING file in this directory for more details.
