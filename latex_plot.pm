################################################################################
# latex_plot.pm
#
# Perl module to generate pretty LaTeX plots from experimental data.
#
# Requires reasonably recent versions of gnuplot, metapost, and latex2e.
#
# Usage:
#
# INITIALIZATION:
# use latex_plot;
# my $lp = new latex_plot
#
# ADDING DATA:
# $lp->add_pt($series_name, $x_val, $y_val);
#       NOTE: For one-dimensional data, the X value is ignored.
#
#
# PLOTTING DATA:
# $lp->plot_lines_and_stdev($x_label, $y_label, $filename);
#
# VIEWING THE PLOT:
# You can view the metapost plot by running it through the "mptopdf" program.
#
# INSERTING PLOTS INTO LATEX DOCS:
# The "plot" subroutines in this file generate metapost output.  Say your
# output file is called "graph.mp".  Then you'll need to do the following
# (with pdflatex, at least) to insert your graph into the paper:
# 
# Add a makefile rule to convert your .mp files into a preprocessed .mps 
# files:
# %.mps : %.mp
#        mpost $<
#        mv $(notdir $(<:.mp=.[01234])) $@
#
# Make your document depend on the .mps file.
# doc.tex: ... graph.mps ...
#       touch doc.tex
#
# Insert the graph in a figure, inside your LaTeX:
# \begin{figure}
# \begin{center}
# \resizebox{3in}{!}{\includegraphics{graph}}
# \end{center}
# \caption{ caption \label{fig:label} }
# \end{figure}
################################################################################

package latex_plot;

use strict;
use warnings;

use Term::ANSIColor;
use Statistics::Descriptive;

use Cwd;

# Stuff copied from the perlmod man pages.
BEGIN {
    use Exporter   ();
    our (@ISA, @EXPORT);

    @ISA         = qw(Exporter);
    @EXPORT      = qw( 
                        &new
                        &add_point
                        &plot_lines_and_stdev
                    );
}

################################################################################
# CONSTANTS
################################################################################

# Template for the mean/stdev plot command file.
my $MEAN_CMD_TEMPLATE = <<'END_STR';

set terminal mp tex
set output "FILENAME_GOES_HERE"

set ylabel "Y_LABEL_GOES_HERE"
set xlabel "X_LABEL_GOES_HERE"


RANGE_STRING_GOES_HERE

set key LEGEND_LOCATION_GOES_HERE
#set nokey;

#set data style linespoints;
PLOT_COMMAND_GOES_HERE

END_STR

# Template for the bar chart command file.
my $BAR_CMD_TEMPLATE = <<'END_STR';

set terminal mp tex
set output "FILENAME_GOES_HERE"

set ylabel "Y_LABEL_GOES_HERE"

set nokey;
set noxtics;

# Leave room for labels.
set yrange [0:*]
set xrange [X_RANGE_GOES_HERE]

LABEL_COMMANDS_GO_HERE

PLOT_COMMAND_GOES_HERE


END_STR




################################################################################
# CONSTRUCTOR
#
# Arguments:
#       <class> is passed by the Perl interpreter.
################################################################################
#sub new($class) {
sub new($) {
    my ($class, @param) = @_;

    # Perl voodoo.  Apparently, this creates the class instance, while
    # allowing for inheritance.
    my $self = {};
    bless $self, ref($class) || $class;

    $self->_initialize(@param);

    return $self;
}

# The subroutine that actually does the initialization.
#sub _initialize($self) {
sub _initialize($) {
    my ($self) = @_;

    my %hash;
    $self->pointsets(\%hash);

    my %otherhash;
    $self->seriesorder(\%otherhash);

    $self->legendloc("top");

    $self->logscale(0);
}

################################################################################
# ACCESSORS
#
# Note that most of these are "private".
################################################################################

# Generic accessor function.
sub _genacc  { # ($self, $val, $name)
    my $self = shift @_;
    my $name = pop @_;

    if (@_) {
	$self->{$name} = shift @_;
    }
    return $self->{$name};
}

# A reference to a hash of sets of points.
sub pointsets {  _genacc(@_, 'pointsets'); }

# A hash that determines the order in which series are printed.
# A mapping from position to series name.
sub seriesorder {  _genacc(@_, 'seriesorder'); }

# A flag that determines the location of the legend.  Default is "top"
# Other valid options are "bottom", "left", "right"
sub legendloc {  _genacc(@_, 'legendloc'); }

# A flag that determines whether to use a log scale.
sub logscale {  _genacc(@_, 'logscale'); }


################################################################################
# METHODS
################################################################################

################################################################################
# SUBROUTINE add_point
# Arguments:
#       <series> is the NAME of the series.
#       <x_val> is the numeric index of a point in the series.
#       <y_val> is the data point to add.
sub add_pt($$$$) {
    my ($self, $series, $x_val, $y_val) = @_;

    my $hash_ref = $self->pointsets;
    
    # Allocate a new hash, if necessary.
    if (! $hash_ref->{$series}) {
#        print "Defining a new hash for series $series.\n";
        my %hash;
        $hash_ref->{$series} = \%hash;
    }

    my $series_hash_ref = $hash_ref->{$series};

    # Allocate a new list for this X value, if necessary.
    my $x_key = sprintf "%5f", $x_val;

    if (! $series_hash_ref->{$x_key}) {
#        print "Defining a new list for point $x_val of series $series\n";
        my @list;
        $series_hash_ref->{$x_key} = \@list;
    }

    my $y_list_ref = $series_hash_ref->{$x_key};

    push @$y_list_ref, $y_val;
}

################################################################################
# SUBROUTINE set_series_position
# Arguments:
#       <series> is the NAME of a series.
#       <order> is an integer specifying the position of the series in the
#               order on the graph.
sub set_series_position($$$) {
    my ($self, $series, $order) = @_;

    my $intorder = int $order;

    die "Non-integral order $order" unless $intorder == $order;

    my $hashref = $self->seriesorder;

    $hashref->{$order} = $series;
}


################################################################################
# SUBROUTINE plot_lines_and_stdev
#
# Plots the points in the object, grouping each series by X value and plotting
# the mean and standard deviation.
#
# Arguments:
#       <x_label> is the label for the X axis.
#       <y_label> is the label for the Y axis.
#       <outputfile> is the metapost output file.
sub plot_lines_and_stdev($$$$) {
    my ($self, $x_label, $y_label, $outputfile) = @_;

    # Generate gnuplot input file for each series.
    my $hash_ref = $self->pointsets;
#    foreach my $series (sort keys %$hash_ref) {
    foreach my $series ($self->get_series_order()) {
        my $filename = tmp_filename($series);
        open DATA, "> $filename";

        my $series_hash_ref = $hash_ref->{$series};

        my ($mean, $stdev);

        # sort numerically ascending
        foreach my $x_val (sort {$a <=> $b} keys %$series_hash_ref) {
            my $y_vals_ref = $series_hash_ref->{$x_val};

            if (1 == (scalar @$y_vals_ref)) {
                # SPECIAL CASE: Singleton list.
                $mean = $y_vals_ref->[0];
                $stdev = 0.0;
                # END SPECIAL CASE.
            } else {
                my $stat = Statistics::Descriptive::Sparse->new();
                $stat->add_data(@$y_vals_ref);
                $mean = $stat->mean();
                $stdev = $stat->standard_deviation();
            }

            print DATA "$x_val, $mean, $stdev\n";
        }

        close DATA;
    }

    # Generate the "plot" command to send to gnuplot.
    my @plot_cmd_lines;

#    foreach my $series (sort keys %$hash_ref) {
    foreach my $series ($self->get_series_order()) {
        my $filename = tmp_filename($series);

        # First we draw the lines.
        push @plot_cmd_lines, 
            "\"$filename\" using 1:2 title \"$series\" with linespoints";

        # Then we draw the points and errorbars.
        push @plot_cmd_lines, 
            "\"$filename\" using 1:2:3 notitle with errorbars pointsize 0";
    }

    my $lines_str = join ", \\\n    ", @plot_cmd_lines;
    my $plot_cmd_str = "plot \\\n    $lines_str\n";

    my $legend_loc = $self->legendloc;

    my $range_str;
    if ($self->logscale) {
        $range_str = "set logscale"; 
    } else {
        # Some of our error bars stick out below zero.
        $range_str = "set yrange [0:*]";
    }

    # Generate a gnuplot command file.
    my $cmd_str = $MEAN_CMD_TEMPLATE;
    $cmd_str =~ s/FILENAME_GOES_HERE/$outputfile/g;
    $cmd_str =~ s/Y_LABEL_GOES_HERE/$y_label/g;
    $cmd_str =~ s/X_LABEL_GOES_HERE/$x_label/g;
    $cmd_str =~ s/PLOT_COMMAND_GOES_HERE/$plot_cmd_str/g;
    $cmd_str =~ s/LEGEND_LOCATION_GOES_HERE/$legend_loc/g;
    $cmd_str =~ s/RANGE_STRING_GOES_HERE/$range_str/g;

    open CMD_FILE, ">/tmp/latex_gnuplot.in";
    print CMD_FILE $cmd_str;
    close CMD_FILE;

    # Run GNUPLOT
    system "gnuplot /tmp/latex_gnuplot.in";
}

################################################################################
# SUBROUTINE plot_named_bars
#
# Plots the points in the object as a bar graph, ignoring the x values and
# plotting the mean and standard deviation.
#
# Arguments:
#       <y_label> is the label for the Y axis.
#       <outputfile> is the metapost output file.
sub plot_named_bars($$$) {
    my ($self, $y_label, $outputfile) = @_;

    # Generate the "plot" command to send to gnuplot.
    my @plot_cmd_lines;
    my @plot_cmd_pts;

    my @label_cmd_lines;

    my $hash_ref = $self->pointsets;

    my $series_num = 1;
    foreach my $series (sort keys %$hash_ref) {
        my $series_hash_ref = $hash_ref->{$series};

        my $stat = Statistics::Descriptive::Sparse->new();

        # Filter out the x values.
        my $last_val = -1;
        foreach my $x_val (keys %$series_hash_ref) {
            my $y_vals_ref = $series_hash_ref->{$x_val};

            $stat->add_data(@$y_vals_ref);

            $last_val = $y_vals_ref->[0];
        }

        my ($mean, $stdev);
        if (1 == $stat->count()) {
            # SPECIAL CASE: Singleton list.
            $mean = $last_val;
            $stdev = 0.0;
            # END SPECIAL CASE.
        } else {
            $mean = $stat->mean();
            $stdev = $stat->standard_deviation();
        }

        push @plot_cmd_lines, "'-' with boxes";

        # We do all the data inline for simplicity.
        my $box_width = 0.8;
        push @plot_cmd_pts, "$series_num $mean $box_width";
        push @plot_cmd_pts, "e";

        push @plot_cmd_lines, "'-' with errorbars";
        push @plot_cmd_pts, "$series_num $mean $stdev";
        push @plot_cmd_pts, "e";

        # Add the labels.
        push @label_cmd_lines, 
            sprintf "set label \"%s\" at %d, %f center", 
                    $series, $series_num, $mean / 2;

        $series_num++;
    }

    my $num_series = $series_num - 1;

    my $x_range_str = sprintf "0.5:%f", $num_series + 0.5;


    my $lines_str = join ", \\\n    ", @plot_cmd_lines;
    my $pts_str = join "\n", @plot_cmd_pts;
    my $plot_cmd_str = "plot \\\n    $lines_str\n$pts_str";
    my $label_cmd_str = join "\n", @label_cmd_lines;

    # Generate a gnuplot command file.
    my $cmd_str = $BAR_CMD_TEMPLATE;
    $cmd_str =~ s/FILENAME_GOES_HERE/$outputfile/g;
    $cmd_str =~ s/Y_LABEL_GOES_HERE/$y_label/g;
    $cmd_str =~ s/X_RANGE_GOES_HERE/$x_range_str/g;
    $cmd_str =~ s/PLOT_COMMAND_GOES_HERE/$plot_cmd_str/g;
    $cmd_str =~ s/LABEL_COMMANDS_GO_HERE/$label_cmd_str/g;

    open CMD_FILE, ">/tmp/latex_gnuplot.in";
    print CMD_FILE $cmd_str;
    close CMD_FILE;

    # Run GNUPLOT
    system "gnuplot /tmp/latex_gnuplot.in";
}


################################################################################
# INTERNALS
################################################################################

# private subroutine that computes temp file names from strings that may
# contain spaces and special chars.
sub tmp_filename($) {
    my ($str) = @_;

    $str =~ s/\W/_/g;

    return "/tmp/$str.csv"; 
}


# Subroutine that calculates the order of the series in the graph.
# Returns a list of series names; first the ones with an explicitly specified
# order, than the rest in alphabetical order.
sub get_series_order($) {
    my ($self) = @_;

    my @order;
        # Will be returned.

    my $hashref = $self->seriesorder;

    # Use a hashtable to keep track of which series are ordered.
    my %ordered_series;

    # First we do the series with explicit orders.
    # Key of the hash is (integer) position.
    foreach my $pos (sort keys %$hashref) {
        my $name = $hashref->{$pos};

        $ordered_series{$name} = 1;

        push @order, $name;
    }

    # Then we do the series without no order specified, in alphabetical order.
    my $ptsetsref = $self->pointsets;

    foreach my $series (sort keys %$ptsetsref) {
        if (! $ordered_series{$series}) {
            push @order, $series;
        }
    }

    my $order_str = join ', ', @order;

    print STDERR "Order of series is $order_str\n";

    return @order;
}

END { }
1;

