package Vmprobe::Viewer;

use common::sense;

use Curses;
use Curses::UI::AnyEvent;

use Vmprobe::Util;
use Vmprobe::RunContext;

use Vmprobe::DB::Probe;
use Vmprobe::DB::EntryByProbe;
use Vmprobe::DB::Entry;



sub new {
    my ($class, %args) = @_;

    my $self = { summaries => {}, };
    bless $self, $class;



    $self->{cui} = Curses::UI::AnyEvent->new(-color_support => 1, -mouse_support => 0, -utf8 => 1);
$self->{cui}->leave_curses(1);
say;

    $self->{cui}->set_binding(sub { exit }, "\cC");
    $self->{cui}->set_binding(sub { exit }, "q");

    $self->{main_window} = $self->{cui}->add('main', 'Window');
    $self->{notebook} = $self->{main_window}->add(undef, 'Notebook');
    $self->{notebook}->set_binding('goto_prev_page', KEY_LEFT());
    $self->{notebook}->set_binding('goto_next_page', KEY_RIGHT());
    $self->{notebook}->set_binding(sub { $self->close_page(); }, 'x');

    $self->new_screen(@{ $args{init_screen} });

    $self->{cui}->draw;
    $self->{cui}->startAsync();

    return $self;
}



sub new_screen {
    my ($self, $view_type, $args) = @_;

    my $screen_id;

    if (exists $args->{probe_id}) {
        $screen_id = "$view_type " . substr($args->{probe_id}, 0, 6) . "...";
    } else {
        $screen_id = $view_type;
    }

    if (!exists $self->{screens}->{$screen_id}) {
        my $page = $self->{notebook}->add_page($screen_id);
        if (!$page) {
            ## can't fit any more in notebook: FIXME: should indicate error
            $Curses::UI::screen_too_small = 0; ## work around curses::ui freezing up
            return;
        }
        $self->{screens}->{$screen_id} = $page;
        $self->{screen_widgets}->{$screen_id} =
            $self->{screens}->{$screen_id}->add("$screen_id widget", "Vmprobe::Viewer::Page::${view_type}", -focusable => 0,
                                                viewer => $self, %$args);
    }

    $self->{notebook}->activate_page($screen_id);
    $self->{notebook}->layout;
    $self->{cui}->draw;
}



sub close_page {
    my ($self) = @_;

    exit if @{ $self->{notebook}->{-pages} } <= 1;

    my $page_id = $self->{notebook}->active_page;

    $self->{notebook}->delete_page($page_id);
    delete $self->{screens}->{$page_id};
    delete $self->{screen_widgets}->{$page_id};
    delete $self->{notebook}->{-id2object}->{$page_id}; ## work-around notebook not cleaning up properly
    $self->{notebook}->layout;
    $self->{cui}->draw;
}




1;
