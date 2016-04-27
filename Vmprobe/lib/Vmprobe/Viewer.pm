package Vmprobe::Viewer;

use common::sense;

use Curses::UI::AnyEvent;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{probe_summaries} = $args{probe_summaries} // die "need probe summaries";
    die "need 1 or more probe summaries" if !@{ $self->{probe_summaries} };

    $self->{cui} = Curses::UI::AnyEvent->new(-color_support => 1, -mouse_support => 0, -utf8 => 1,);
#$self->{cui}->leave_curses;

    $self->{cui}->set_binding(sub { exit }, "\cC");
    $self->{cui}->set_binding(sub { exit }, "q");

    $self->{main_window} = $self->{cui}->add('main', 'Window');
    $self->{notebook} = $self->{main_window}->add(undef, 'Notebook');

    foreach my $summary (@{ $self->{probe_summaries} }) {
        my $page = $self->{notebook}->add_page($summary->{probe_id});

        $self->{probes}->{$summary->{probe_id}} =
             {
                 page => $page,
                 summary => $summary,
             };
    }

    $self->{cui}->draw;
    $self->{cui}->startAsync();

    return $self;
}



sub update {
    my ($self, $update) = @_;
}


sub create_probe_page {
    my ($self, $probe) = @_;

    my $page = $self->{notebook}->add_page("Probes");
    $self->render_probe_page();
}

sub render_probe_page {
    my $self = shift;

    my $l = $self->{probe_page}->add('blah', 'Label',
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -x => 0,
                               -border => 1,
                               -fg => 'red',
                               -focusable => 0,
                             );
$l->text("hi\x{2588}\x{2586}\x{2584} \x{033d}\x{033c}' \x{2591}\x{2592}\x{2593}");

    my $l2 = $self->{probe_page}->add('blah 2', 'Vmprobe::Viewer::Probe',
                               -y => 7,
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -border => 1,
                               -focusable => 0,
                             );



    my $l3 = $self->{probe_page}->add('blah 3', 'Vmprobe::Viewer::Probe',
                               -y => 14,
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -border => 1,
                               -focusable => 0,
                             );
$self->{notebook}->set_binding(sub { $l->focus(); }, "1");
}





1;
