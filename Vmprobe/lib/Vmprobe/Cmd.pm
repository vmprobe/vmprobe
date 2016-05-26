package Vmprobe::Cmd;

use common::sense;

use Exporter 'import';
our @EXPORT = qw(opt argv);

use EV;

use Getopt::Long qw(:config default bundling no_ignore_case no_auto_abbrev);
use YAML;

use Vmprobe;
use Vmprobe::Util;


our $opt = {};
our $argv;



sub opt {
    my $cmd = shift;

    if (!defined $cmd) {
        ($cmd) = caller();

        $cmd =~ s/^Vmprobe::Cmd:://;
    }

    die "no opt hash found for command $cmd" if !exists $opt->{$cmd};

    return $opt->{$cmd};
}


sub argv {
    return $argv;
}



sub run_cmd {
    my ($cmd, $args) = @_;

    my $dir = __FILE__;
    $dir =~ s{\.pm$}{/};

    run_cmd_aux([$cmd], $dir, $args);
}

sub run_cmd_aux {
    my ($full_cmd, $dir, $args) = @_;

    my $cmd_short = join("::", @$full_cmd);
    my $cmd_long = "Vmprobe::Cmd::$cmd_short";

    my $o = {};
    my @getopt_specs;
    my $next_cmd;

    eval {
        require("$dir$full_cmd->[-1].pm");
    };

    if ($@) {
        my $path = join('/', @$full_cmd) . '.pm';
        if ($@ !~ m{^Can't locate \S+\Q$path\E in}) {
            die "\nError compiling $full_cmd->[-1].pm:\n\n$@\n";
        }

        my $msg = 'no such sub-command "' . join(' ', @$full_cmd) . '"';
        pop @$full_cmd;
        $dir =~ s{[^/]*/?$}{};
        show_help($msg, $full_cmd, $dir);
        exit 1;
    }

    my $yaml_spec = load_yaml_spec($full_cmd);

    foreach my $k (keys %{ $yaml_spec->{opt} }) {
        my $v = $yaml_spec->{opt}->{$k};

        my $opt_name = $k;
        $opt_name .= "|$v->{alias}" if exists $v->{alias};

        if ($v->{type} eq 'Str') {
            $opt_name .= '=s';
        } elsif ($v->{type} eq 'Str[]') {
            $opt_name .= '=s@';
        }

        push @getopt_specs, $opt_name;
    }

    push @getopt_specs, 'help|?';

    if (!exists $yaml_spec->{argv}) {
        push @getopt_specs, '<>';
        $o->{'<>'} = sub {
            $next_cmd = $_[0];
            die "!FINISH";
        };
    }


    {
        my $msg;

        local $SIG{__WARN__} = sub {
            $msg = shift;
            chomp $msg;
        };

        if (!Getopt::Long::GetOptionsFromArray($args, $o, @getopt_specs)) {
            show_help("error parsing arguments: $msg", $full_cmd, $dir);
            exit 1;
        }
    }


    if ($o->{help}) {
        show_help('', $full_cmd, $dir);
        exit 0;
    }


    foreach my $k (keys %{ $yaml_spec->{opt} }) {
        my $v = $yaml_spec->{opt}->{$k};

        $o->{$k} = $v->{default} if exists $v->{default} && !exists $o->{$k};
    }


    $opt->{$cmd_short} = $o;

    if (defined &{ "${cmd_long}::validate" }) {
        my $validate = \&{ "${cmd_long}::validate" };

        eval {
            $validate->();
        };

        my $err = $@;

        if ($err) {
            $err = abbreviate_perl_exception($err);

            show_help("validation failure: $err", $full_cmd, $dir);
            exit 1;
        }
    }


    if (defined $next_cmd) {
        if (exists $yaml_spec->{argv}) {
            unshift @$args, $next_cmd;
        } else {
            run_cmd_aux([@$full_cmd, $next_cmd], "$dir$full_cmd->[-1]/", $args);
            return;
        }
    }

    $argv = $args;

    my $run;

    {
        no strict 'refs';
        $run = \&{ "${cmd_long}::run" }
            if defined &{ "${cmd_long}::run" };
    }

    if (!$run) {
        show_help('no sub-command specified', $full_cmd, $dir) if !$run;
        exit 1;
    }

    $run->();
}


sub load_yaml_spec {
    my ($full_cmd) = @_;

    my $cmd_long = "Vmprobe::Cmd::" . join("::", @$full_cmd);

    my $yaml_spec;

    {
        no strict 'refs';
        $yaml_spec = ${ "${cmd_long}::spec" } // '';
    }

    eval {
        $yaml_spec = YAML::Load($yaml_spec);
    };

    if ($@) {
        die "error parsing YAML in command: $@";
    }

    return $yaml_spec;
}


sub show_help {
    my ($msg, $full_cmd, $dir) = @_;

    my $yaml_spec = load_yaml_spec($full_cmd);

    my $cmd_name = $full_cmd->[-1];
    my $cmd_pretty = '"' . colour(join(' ', @$full_cmd), 'bold white') . '"';

    my @sub_commands;
    my $cmd_dir = "$dir/$cmd_name";

    if (-d $cmd_dir) {
        opendir(my $dh, $cmd_dir) || die "can't opendir $cmd_dir: $!";

        while(my $filename = readdir $dh) {
            if (-d && $filename =~ !/^\./) {
                push @sub_commands, "$filename/";
            } elsif ($filename =~ /\.pm$/) {
                $filename =~ s/\.pm$//;
                push @sub_commands, $filename;
            }
        }

        @sub_commands = sort @sub_commands;
    }


    print "vmprobe $Vmprobe::VERSION (C) 2016 Vmprobe Inc.\n\n";

    print "Help for $cmd_pretty:\n";

    my $doc = $yaml_spec->{doc};
    $doc =~ s/\n*\z//;
    print "    $doc\n" if $doc;
    say;

    if (@sub_commands) {
        say "$cmd_pretty requires a sub-command:";
        foreach my $cmd (@sub_commands) {
            say "    $cmd";
        }
        say;
    }

    if (exists $yaml_spec->{argv}) {
        print "$cmd_pretty accepts arguments: $yaml_spec->{argv}\n\n";
    }

    my $opts = $yaml_spec->{opt};

    if (keys %$opts) {
        require Text::Wrapper;

        my $wrapper = Text::Wrapper->new(columns => 60, body_start => " "x8);

        say "$cmd_pretty accepts the following options:";

        foreach my $name (sort keys %$opts) {
            my $spec = $opts->{$name};
            print "    --$name";
            print "/-$spec->{alias}" if exists $spec->{alias};
            print " ($spec->{type})";
            say;

            print " "x8 . $wrapper->wrap($spec->{doc}) if $spec->{doc};

            my $default = ref($spec->{default}) ? '[' . join(' ', @{ $spec->{default} }) . ']'
                                                : $spec->{default};

            say " "x10 . "Default: $default" if $default;
        }

        say;
    }

    print colour("*** $msg ***\n", 'red') if $msg;

    say;
}



1;
