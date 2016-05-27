package Vmprobe::Util;

use common::sense;

use Carp;

use Exporter 'import';
our @EXPORT = qw(pages2size colour get_session_token abbreviate_perl_exception sereal_encode sereal_decode curr_time format_duration);



sub term_dims {
    require Term::Size;

    my ($term_cols, $term_rows) = Term::Size::chars(*STDOUT{IO});

    $term_cols //= 80;

    return ($term_cols, $term_rows);
}


sub load_file {
    my $filename = shift;

    my $fh;

    if (!defined $filename || $filename eq '-') {
        $fh = \*STDIN;
        binmode $fh;
    } else {
        open($fh, '<:raw', $filename) || die "couldn't open $filename for reading: $!";
    }

    my $file;

    {
        local $/;
        $file = <$fh>;
    }

    return $file;
}



sub pages2size {
    use integer; ## FIXME: show a decimal place?

    my $pages = shift;
    my $pagesize = shift // 4096;

    $pages *= $pagesize;

    $pages /= 1024;
    return "${pages}K" if $pages < 1024;

    $pages /= 1024;
    return "${pages}M" if $pages < 1024;

    $pages /= 1024;
    return "${pages}G" if $pages < 1024;

    $pages /= 1024;
    return "${pages}T";
}



sub format_duration {
    my $dur = shift;
    my $show_short = shift;

    if ($dur < 1) {
        return sprintf("%.1fms", 1000.0 * $dur) if $show_short;
        return "<1s";
    } elsif ($dur < 60) {
        return sprintf("%ds", int($dur)) if $show_short;
        return "<1m";
    } elsif ($dur < 3600) {
        return sprintf("%dm", int($dur/60));
    } elsif ($dur < 86400) {
        return sprintf("%dh%dm", int($dur/3600), int(($dur%3600)/60));
    } else {
        return sprintf("%dd%dh%dm", int($dur/86400), int(($dur%86400)/3600), int(($dur%3600)/60));
    }
}



## FIXME: deprecated
sub format_time {
    my $time = shift;

    if ($time < 1) {
      return sprintf("%.1fms", $time * 1000.0);
    }

    return sprintf("%.1fs", $time);
}



sub colour {
    my $text = shift;
    my $colour = shift;

    return $text if !-t STDOUT;

    require Term::ANSIColor;

    return Term::ANSIColor::colored($text, $colour);
}



sub is_valid_package_name {
    my $name = shift;

    return !!($name =~ m{\A\w+(?:::\w+)*\z});
}



sub capture_stderr (&@) {
    my ($code, @args) = @_;

    require Guard;

    open(my $old_err, '>&', \*STDERR) || die "can't dup STDERR: $!";

    Guard::scope_guard(sub {
        open(STDERR, ">&", $old_err) || die "couldn't restore STDERR: $!";
    });

    pipe(my $pipe_r, my $pipe_w) || die "can't pipe: $!";

    open(STDERR, '>&', $pipe_w) or die "Can't dup2: $!";

    $code->();

    return $pipe_r;
}



sub get_session_token {
    state $generator = do {
        require Session::Token;
        Session::Token->new
    };

    return $generator->get;
}



sub abbreviate_perl_exception {
    my ($err) = @_;

    $err =~ s/at \S+ line \d+\.\s*\z//;

    return $err;
}


sub sereal_encode {
    state $encoder = do {
        require Sereal::Encoder;
        Sereal::Encoder->new({ compress => Sereal::Encoder::SRL_ZLIB(), })
    };

    return $encoder->encode($_[0]);
}

sub sereal_decode {
    state $decoder = do {
        require Sereal::Decoder;
        Sereal::Decoder->new()
    };

    my $decoded;

    eval {
        $decoded = $decoder->decode($_[0]);
    };

    if ($@) {
        croak "$@ (" . substr($_[0], 0, 100) . ")";
    }

    return $decoded;
}


sub curr_time () {
    require Time::HiRes;

    my @t = Time::HiRes::gettimeofday();

    return $t[0]*1_000_000 + $t[1];
}



sub parse_key_value {
    my $str = shift;

    my $o = {};

    foreach my $kv (split /\s+/, $str) {
        $kv =~ /\A([^=]+)=(\S+)/ || die "no = character found";
        $o->{$1} = $2;
    }

    return $o;
}



## Returns number of pages required to hold this size

sub parse_size {
    my $spec = shift;

    $spec =~ m{^([\d.]+)([a-zA-Z]?)$} || die "invalid size spec: '$spec' (should be like '4k' or '1.2G')";

    my ($num, $unit) = ($1, $2);
    $unit = lc($unit) if defined $unit;

    my $bytes;

    if (!$unit) {
        $bytes = $num;
    } elsif ($unit eq 'k') {
        $bytes = $num * 1024;
    } elsif ($unit eq 'm') {
        $bytes = $num * 1024 * 1024;
    } elsif ($unit eq 'g') {
        $bytes = $num * 1024 * 1024 * 1024;
    } elsif ($unit eq 't') {
        $bytes = $num * 1024 * 1024 * 1024 * 1024;
    }

    return int(($bytes + 4095) / 4096);
}



sub buckets_to_rendered {
    my ($parsed) = @_;

    return join('',
                map {
                    $_ == 0 ? ' ' :
                    $_ == $parsed->{pages_per_bucket} ? "\x{2588}" :
                    chr(0x2581 + int(8 * $_ / $parsed->{pages_per_bucket}))
                }
                @{ $parsed->{buckets} });
}


1;
