################################################################################
# Package pretty
#
# Contains subroutines for pretty-printing the status of perl scripts.
################################################################################


package pretty;

use strict;
use warnings;

use Term::ANSIColor;
use Time::HiRes qw( usleep gettimeofday tv_interval );

use sqlstuff_constants;
use loadexp;


# Stuff copied from the perlmod man pages.
BEGIN {
    use Exporter   ();
    our (@ISA, @EXPORT);

    @ISA         = qw(Exporter);
    @EXPORT      = qw( 
                        &clear_line
                        &status_inflight
                        &status_now
                        &status_graph
                        &status_done
                        &please_wait
                    );
}

################################################################################
# Constants that control the behavior of subroutines in this file.

# The minimum number of seconds between writes to the screen from
# status_inflight().
our $MIN_UPDATE_INTERVAL_SEC = 0.1;

# How long is a line on our terminal?
our $LINE_LEN = 80;

################################################################################
# "current status" mechanism

# Subroutine that clears the current line of STDERR
sub clear_line($) {
    my ($len) = @_;

    my $str = "";
    for (my $i = 0; $i < $len; $i++) {
        $str .= " ";
    }

    print STDERR "\r$str\r";
}


# Subroutine that pads a string with spaces out to the indicated length.
sub pad_str($$) {
    my ($str, $len) = @_;

    my $result = sprintf "%-${len}s", $str;

    return $result;
}

# Subroutine that turns off buffering for STDERR, saving the current setting.
our $g_orig_buf = 1;
sub turn_off_buf_stderr() {
    select STDERR; 
    $g_orig_buf = $|;
    $| = 0;
    select STDOUT;
}

sub reinstate_buf_stderr() {
    select STDERR; 
    $| = $g_orig_buf;
    select STDOUT;
}

# Subroutines for keeping track of when we did our last write to the screen.
our $g_last_write_time = undef;
our $g_last_gettimeofday_time = undef;
sub time_since_last_write() {

    $g_last_gettimeofday_time = my $cur_time = [gettimeofday];
    my $elapsed;

    # SPECIAL CASE: If we have never written to the screen, in recent memory
    # return a suitably large value.
    if (defined $g_last_write_time) {
        $elapsed = tv_interval($g_last_write_time, $cur_time);
    } else {
        $elapsed = $MIN_UPDATE_INTERVAL_SEC + 1;
    }
    # END SPECIAL CASE

    return $elapsed;
}
sub note_write() {
    # Assume that negligible time has elapsed since the last call to
    # gettimeofday().
    if (defined $g_last_gettimeofday_time) {
        $g_last_write_time = $g_last_gettimeofday_time;
    } else {
        $g_last_write_time = [gettimeofday];
    }
}
sub reset_write_timer() { $g_last_write_time = undef; }

# Subroutine to put up a "status" message for an action that's in progress.
# Doesn't write to the screen if we've written to the screen recently.
sub status_inflight($) {
    my ($msg) = @_;

    # Check to see if we've exceeded the time limit on how long we wait
    # between writes.
    if (time_since_last_write() < $MIN_UPDATE_INTERVAL_SEC) {
        return;
    }

    status_now($msg);

    # Make a note of the fact that we just wrote, so that we can avoid writing
    # again too soon.
    note_write();
}

# Version of status_inflight() that will print to the screen regardless of
# whether we've sent text to the screen recently.
sub status_now($) {
    my ($msg) = @_;


    my $trunc_msg = substr $msg, 0, $LINE_LEN;

    turn_off_buf_stderr();

    # Clear the line.
    clear_line($LINE_LEN);
    print STDERR "$trunc_msg\r";

    reinstate_buf_stderr();

}

# Subroutine for simultaneously putting up the current status and displaying a
# graph of how far along the current step is.  Second and third arguments are
# the current position in the job and the maximum position.  Optional fourth
# argument is graph color.
sub status_graph($$$) {
    my ($msg, $cur_pos, $max_pos, $color) = @_;

    # Apply user-defined color, if applicable, by turning it into a background
    # color.
    my $DEFAULT_BAR_COLOR = 'on_red';
    my $bar_color = $DEFAULT_BAR_COLOR;
    if (defined $color) {
        $bar_color = "on_$color";
    }


    # Don't bother computing the string to print if we're not going to
    # write it to the terminal.
    if (time_since_last_write() < $MIN_UPDATE_INTERVAL_SEC) {
        return;
    }

    die "Negative position" if $cur_pos < 0;

    my $cur_fract = $cur_pos / $max_pos;

    if ($cur_fract > 1.0) { $cur_fract = 1.0; }

    # Apply the bar color to $cur_fract of the line.
    my $bar_len = int($cur_fract * $LINE_LEN);


    # Pad the message out to the appropriate line length.
    my $trunc_msg = substr $msg, 0, $LINE_LEN;
    $trunc_msg = pad_str($trunc_msg, $LINE_LEN);


    my $bar_part = substr $trunc_msg, 0, $bar_len;
    my $non_bar_part = substr $trunc_msg, $bar_len;

    $bar_part = colored $bar_part, $BAR_COLOR;

    # We would like to use status_now() here to do the printing, but the
    # control characters interfere with status_now()'s code for truncating
    # strings to one line.
    turn_off_buf_stderr();
    print STDERR "\r" . $bar_part . $non_bar_part . "\r";
    reinstate_buf_stderr();

    # Make a note of the fact that we just wrote, so that we can avoid writing
    # again too soon.
    note_write();
}

# Subroutine to put up a "status" message for an action that's done.
# Also erases anything printed by an "in progress" action.
sub status_done($) {
    my ($msg) = @_;


    my $trunc_msg = substr $msg, 0, $LINE_LEN;

    clear_line($LINE_LEN);
    print STDERR "\r$trunc_msg\n";

    # Make sure the next call to status_inflight() will print out something.
    reset_write_timer();
}

################################################################################
# Subroutine that pretty-prints a "please wait" message.
# First argument is the message, second is the color, and third is the number
# of seconds to delay.
sub please_wait($$$) {
    my ($msg, $color, $seconds) = @_;

    print STDERR colored $msg, $color;

    for (my $i = 0; $i < $seconds; $i++) {
        status_graph($msg, $i, $seconds, $color);
        sleep 1;
    }

    status_done "$msg Done.";

    # Restore buffering settings.
    $| = $orig_buf; 
    select STDOUT; 
}


END { }

1;

