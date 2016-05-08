package Vmprobe::Viewer;

use common::sense;

use Curses;
use Curses::UI::AnyEvent;

use Vmprobe::Util;
use Vmprobe::RunContext;

use Vmprobe::DB::Probe;
use Vmprobe::DB::EntryByProbe;
use Vmprobe::DB::Entry;


our $help_text = q{vmprobe viz help

left/right - switch tabs
up/down    - select probe
enter      - open probe in new tab
?          - this help screen
x          - close tab
q          - quit
};


sub new {
    my ($class, %args) = @_;

    my $self = { summaries => {}, };
    bless $self, $class;



    $self->{cui} = Curses::UI::AnyEvent->new(-color_support => 1, -mouse_support => 0, -utf8 => 1);

    $self->{cui}->set_binding(sub { exit }, "\cC");
    $self->{cui}->set_binding(sub { exit }, "q");
    $self->{cui}->set_binding(sub { $self->{cui}->dialog(-message => $help_text) }, "?");

    $self->{main_window} = $self->{cui}->add('main', 'Window');
    $self->{notebook} = $self->{main_window}->add(undef, 'Notebook');
    $self->{notebook}->set_binding('goto_prev_page', KEY_LEFT());
    $self->{notebook}->set_binding('goto_next_page', KEY_RIGHT());
    $self->{notebook}->set_binding(sub { $self->close_page(); }, 'x');

    $self->{probes_list_page} = $self->{notebook}->add_page("Probes");
    $self->{probes_list_page_widget} =
        $self->{probes_list_page}->add('probes list page', 'Vmprobe::Viewer::ProbeList', -focusable => 0, viewer => $self, -intellidraw => 1);


    $self->{cui}->draw;
    $self->{cui}->startAsync();

    return $self;
}



sub open_probe_screen {
    my ($self, $probe_id) = @_;

    if (!exists $self->{probe_screens}->{$probe_id}) {
        my $page = $self->{notebook}->add_page($probe_id);
        if (!$page) {
            ## can't fit any more in notebook: FIXME: should indicate error
            $Curses::UI::screen_too_small = 0; ## work around curses::ui freezing up
            return;
        }
        $self->{probe_screens}->{$probe_id} = $page;
        $self->{probe_screen_widgets}->{$probe_id} =
            $self->{probe_screens}->{$probe_id}->add("$probe_id widget", 'Vmprobe::Viewer::Probe', -focusable => 0,
                                                     viewer => $self, probe_id => $probe_id);
    }

    $self->{notebook}->activate_page($probe_id);
    $self->{notebook}->layout;
    $self->{cui}->draw;
}



sub close_page {
    my ($self) = @_;

    return if @{ $self->{notebook}->{-pages} } <= 1;

    my $page_id = $self->{notebook}->active_page;

    $self->{notebook}->delete_page($page_id);
    delete $self->{probe_screens}->{$page_id}; ## FIXME: not necessarily a probe page
    delete $self->{probe_screen_widgets}->{$page_id}; ## FIXME: not necessarily a probe page
    delete $self->{notebook}->{-id2object}->{$page_id}; ## work-around notebook not cleaning up properly
    $self->{notebook}->layout;
    $self->{cui}->draw;
}




1;
