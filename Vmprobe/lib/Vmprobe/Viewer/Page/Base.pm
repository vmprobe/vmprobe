package Vmprobe::Viewer::Page::Base;

use common::sense;

use Curses;
use Class::ISA;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::Entry;

use parent 'Curses::UI::Widget';



our $bindings = [
    {
        key => '?',
        desc => 'this help screen',
        cb => sub { my $self = shift; $self->root->dialog(-message => $self->_help_text_wrapper()) },
    },

    ## Implemented by viewer
    {
        key => 'left/right',
        desc => 'switch tabs',
    },
    {
        key => 'x',
        desc => 'close current tab',
    },
    {
        key => 'q/control-c',
        desc => 'quit',
    },
];



sub new {
    my ($class, %userargs) = @_;

    my %args = (
        %userargs,
    );

    my $self = $class->SUPER::new( %args );

    $self->_install_bindings;

    $self->init;

    return $self;
}


sub _help_text_wrapper {
    my ($self) = @_;

    my $output = '';

    foreach my $pkg (Class::ISA::self_and_super_path(ref $self)) {
        my $package_bindings;

        {
            no strict "refs";
            $package_bindings = ${ "${pkg}::bindings" };
        }

        foreach my $b (@$package_bindings) {
            $output .= sprintf("%-15s - %s\n", $b->{key}, $b->{desc})
                if defined $b->{key} && defined $b->{desc};
        }

        $output .= "\n";
    }

    return $output;
}


sub _install_bindings {
    my ($self) = @_;

    foreach my $pkg (Class::ISA::self_and_super_path(ref $self)) {
        my $package_bindings;

        {
            no strict "refs";
            $package_bindings = ${ "${pkg}::bindings" };
        }

        foreach my $b (@$package_bindings) {
            $self->set_binding($b->{cb}, $b->{key})
                if defined $b->{key} && defined $b->{cb};
        }
    }
}


sub redraw {
    my $self = shift;

    $self->schedule_draw(1);
    $self->draw(0) if !$self->hidden && $self->in_topwindow;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;

    $self->render($self->{-canvasscr});

    $self->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
}


sub render {
    die "must implement render";
}


sub init {}



1;
