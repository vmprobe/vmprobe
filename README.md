# vmprobe

[official website](http://vmprobe.com)

## Introduction

vmprobe is a utility for managing the virtual memory of your cloud, cluster, or servers. It is based on [vmtouch](http://hoytech.com/vmtouch/) technology but it adds many new features, and two new interfaces:

* A powerful [command-line client](http://vmprobe.com/command-line)
* An intuitive [web GUI](http://vmprobe.com/web-gui-tutorial)

In our opinion, the main feature that sets vmprobe apart from other sysadmin tools is that vmprobe is designed from the start to operate on distributed collections of machines that are typical in modern architectures. As much as possible, vmprobe removes the distinction between local and remote administration.

**NOTE**: vmprobe is currently very much in beta: There are a few known bugs and a tonne of other features we plan on adding!


## Installing

The [http://vmprobe.com/install](vmprobe installation guide) should have platform-specific instructions as well as links to the latest builds, but for now you must either install from source (see the contributing section below), or from CPAN.

If you have [cpanminus](https://metacpan.org/pod/App::cpanminus) installed, this should be as easy as:

    cpanm Vmprobe --sudo

(but please be patient while it downloads, installs, and tests vmprobe and its dependencies)


## Contributing

If you would like to contribute to vmprobe, first of all: thank you!

Please [create a github issue](https://github.com/vmprobe/vmprobe/issues/new) with any bug report, feature request, or even general question relating to vmprobe.

To develop on vmprobe itself, please see [our contributing guide](http://vmprobe.com/contributing) which should have all the steps needed to get started (if you run into any trouble, please file a github issue).


## License

vmprobe is (C) 2016 by Doug Hoyte and Vmprobe Inc.

It is distributed under the [GNU GPL version 3](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.

Please see the COPYING file in this directory for more details.
