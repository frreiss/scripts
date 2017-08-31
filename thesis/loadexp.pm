
################################################################################
# loadexp.pm 
#
# Module containing subroutines and constants for loading the experiment
# database.
################################################################################

package loadexp;

use strict;
use warnings;

use dist;
    # My package for doing random distributions.

#
# GENERAL CONSTANTS
#

# How much of an initial delay (for starting up streams) in usec?
my $INITIAL_DELAY_USEC = 5000000;

# How many tuples in each of our tables?
# Numbers given here are to be multiplied by the "scaling factors" fed to the
# loading functions.

# Tables in create_simple.sql...
my $NUM_R_TUPLES = 1.0;
my $NUM_S_TUPLES = 1.0;
my $NUM_T_TUPLES = 1.0;
my $NUM_U_TUPLES = 2.0;

my $NUM_RST_COL_VALS = 100;
    # Values of the (integer) columns in R, S, and T range from 1 to this
    # number.

# Tables in create_auction.sql...
my $NUM_CATEGORIES = 20;
my $NUM_CATEGORY_TUPLES = $NUM_CATEGORIES;
my $NUM_ITEM_TUPLES = 100;
my $NUM_FCP_TUPLES = $NUM_ITEM_TUPLES;
    # FCP == FakeCurrentPrice
my $NUM_CA_TUPLES = $NUM_ITEM_TUPLES;
    # CA == ClosedAuction

# How likely is a tuple to be part of a burst?
my $R_BURST_PROB = 0.6;
my $S_BURST_PROB = 0.6;
my $T_BURST_PROB = 0.6;
my $U_BURST_PROB = 0.6;

my $R_BURST_LEN = 100;
my $S_BURST_LEN = 100;
my $T_BURST_LEN = 100;
my $U_BURST_LEN = 100;

my $CATEGORY_BURST_PROB = 0.0;
my $ITEM_BURST_PROB = 0.2;
my $FCP_BURST_PROB = 0.3;
my $CA_BURST_PROB = 0.1;

my $CATEGORY_BURST_LEN = 100;
my $ITEM_BURST_LEN = 100;
my $FCP_BURST_LEN = 100;
my $CA_BURST_LEN = 100;

# What are the data rates of the different streams?
# (e.g. how many time units between tuples)
#
# NOTE: The length of a "time unit" is determined by the argument passed to
# load_simple() and other similar functions.

# "Simple" schema
my $R_BURST_RATE = 1;
my $S_BURST_RATE = 1;
my $T_BURST_RATE = 1;
my $U_BURST_RATE = 1;

my $R_NONBURST_RATE = 20;
my $S_NONBURST_RATE = 20;
my $T_NONBURST_RATE = 20;
my $U_NONBURST_RATE = 20;

# "Auction" schema
my $CA_BURST_RATE = 1;
my $ITEM_BURST_RATE = 1;
my $FCP_BURST_RATE = 1;

my $CA_NONBURST_RATE = 10;
my $ITEM_NONBURST_RATE = 10;
my $FCP_NONBURST_RATE = 10;

# How long a queue do we have for each table?
my $STREAM_Q_LEN = 10;

# How many time units does the drop-only architecture need to process a tuple?
my $DO_PROCESS_TUPLE_TIME = 10;

# How many time units does the signal/noise architecture need to process a
# tuple?
my $SN_PROCESS_TUPLE_TIME = 15;

# How many time units does the signal/noise architecture need to summarize a
# tuple?
my $SN_SUMMARIZE_TUPLE_TIME = 1;


# With what probability do the different architectures drop tuples?
my $DO_NONBURST_DROP_PROB = 0.001;
my $DO_BURST_DROP_PROB = 0.9;
    # Drop-only
my $SN_NONBURST_DROP_PROB = 0.01;
my $SN_BURST_DROP_PROB = 0.95;
    # Signal/noise


my $DATA_TMP_FILE = "/tmp/loaddemo_tmp.csv";
my $DATA_TMP2_FILE = "/tmp/loaddemo_tmp2.csv";
my $CMD_TMP_FILE = "/tmp/loaddemo_cmd_tmp.sql";

# Subroutine to generate the temp file name for a table.
sub tmp_file_name($) {
    my ($tabname) = @_;
    return "/tmp/${tabname}_tmp.csv";
}


# A "null" value for a tuple.
my $NOT_A_TUPLE = "not a tuple";


#
# DISTRIBUTIONS
#

# Distributions from which the tuples in each table are drawn.

my $g_r_nonburst_dist = new dist(1, $NUM_RST_COL_VALS);
my $g_r_burst_dist = new dist(1, $NUM_RST_COL_VALS);

# The non-burst part of R.
#my $g_r_nonburst_dist = new dist(1, $NUM_RST_COL_VALS);

# The burst portion of R.  Should be quite different from the nonburst one.
#my $g_r_burst_dist = new dist(1, $NUM_RST_COL_VALS);

# The non-burst part of S.
my $g_s_nonburst_dist = new dist(2, $NUM_RST_COL_VALS);

# The burst portion of S.  Should be quite different from the nonburst one.
my $g_s_burst_dist = new dist(2, $NUM_RST_COL_VALS);

# t doesn't change either
my $g_t_dist = new dist(1, $NUM_RST_COL_VALS);

my $g_u_dist = new dist(2, $NUM_RST_COL_VALS);


# TODO: Change the following old-style distributions to the new ones.

# The combined distribution of the categoryID and price.  First dimension is
# category ID, and second is price.

# First, we define a couple of distributions for the prices within a category.
my @CHEAP_CAT_DIST =
(
    [10],
    [20],
    [50],
    [50],
    [20],
    [10],
    [5],
    [2],
    [1],
    [0.5],
    [0.2],
    [0.1],
    [0.05],
    [0.02],
    [0.01],
    [0.005],
    [0.002],
    [0.001],
    [0.0005],
    [0.0002]
);

my @EXPENSIVE_CAT_DIST =
(
    [0.0002],
    [0.0005],
    [0.001],
    [0.002],
    [0.005],
    [0.01],
    [0.02],
    [0.05],
    [0.1],
    [0.2],
    [0.5],
    [1],
    [2],
    [5],
    [10],
    [20],
    [50],
    [50],
    [20],
    [10]
);

my @MEDIUM_CAT_DIST =
( 
    [1],
    [2],
    [3],
    [4],
    [6],
    [9],
    [15],
    [20],
    [25],
    [28],
    [30],
    [28],
    [25],
    [20],
    [15],
    [9],
    [6],
    [4],
    [3],
    [2]
);

# Then we build the joint distribution out of references to these pricing
# types.
my @CATID_PRICE_JOINT_NONBURST_DIST =
(
    [20, \@EXPENSIVE_CAT_DIST],
    [19, \@EXPENSIVE_CAT_DIST],
    [18, \@EXPENSIVE_CAT_DIST],
    [17, \@EXPENSIVE_CAT_DIST],
    [16, \@EXPENSIVE_CAT_DIST],
    [15, \@MEDIUM_CAT_DIST],
    [14, \@CHEAP_CAT_DIST],
    [13, \@EXPENSIVE_CAT_DIST],
    [12, \@MEDIUM_CAT_DIST],
    [11, \@CHEAP_CAT_DIST],
    [10, \@EXPENSIVE_CAT_DIST],
    [9, \@MEDIUM_CAT_DIST],
    [8, \@CHEAP_CAT_DIST],
    [7, \@EXPENSIVE_CAT_DIST],
    [6, \@MEDIUM_CAT_DIST],
    [5, \@CHEAP_CAT_DIST],
    [4, \@EXPENSIVE_CAT_DIST],
    [3, \@MEDIUM_CAT_DIST],
    [2, \@CHEAP_CAT_DIST],
    [1, \@EXPENSIVE_CAT_DIST]
);

my @CATID_PRICE_JOINT_BURST_DIST =
(
    [0, \@CHEAP_CAT_DIST],
    [0, \@EXPENSIVE_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [0, \@CHEAP_CAT_DIST],
    [0, \@EXPENSIVE_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [0, \@CHEAP_CAT_DIST],
    [0, \@EXPENSIVE_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [0, \@CHEAP_CAT_DIST],
    [0, \@EXPENSIVE_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [0, \@CHEAP_CAT_DIST],
    [2, \@CHEAP_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [5, \@EXPENSIVE_CAT_DIST],
    [0, \@EXPENSIVE_CAT_DIST],
    [0, \@MEDIUM_CAT_DIST],
    [0, \@CHEAP_CAT_DIST],
    [10, \@CHEAP_CAT_DIST]
);


# Forward declarations of subroutine prototypes, to make the Perl parser happy.
sub get_enter_burst_prob($$);
sub get_exit_burst_prob($$);

#
# EXPERIMENT PARAMETERS
#

# Parameters for the different types of simulated load in the experiments.
# 
# Each parameter is in the form of a list of arguments to the appropriate
# function.
#
# In the case of R, S, and T, this function is load_table.

# The ``low load'' case.
my @LL_R_PARAMS = 
(
    0.0,                    # Probability of entering a burst.
    1.0,                    # Probability of leaving a burst.
    $g_r_nonburst_dist,    # Data distribution during non-burst times.
    $g_r_burst_dist        # Data distribution during burst times.
);

my @LL_S_PARAMS = 
(
    0.0,                    # Probability of entering a burst.
    1.0,                    # Probability of leaving a burst.
    $g_s_nonburst_dist,             # Data distribution during non-burst times.
    $g_s_burst_dist              # Data distribution during burst times.
);

my @LL_T_PARAMS = 
(
    0.0,                    # Probability of entering a burst.
    1.0,                    # Probability of leaving a burst.
    $g_t_dist,             # Data distribution during non-burst times.
    $g_t_dist              # Data distribution during burst times.
);

my @LL_U_PARAMS = 
(
    0.0,                    # Probability of entering a burst.
    1.0,                    # Probability of leaving a burst.
    $g_u_dist,             # Data distribution during non-burst times.
    $g_u_dist              # Data distribution during burst times.
);


# Parameters for the Item and FakeCurrentPrice tables.
my @LL_ITEM_FCP_PARAMS =
(
    0.0,                    # Probability of entering a burst.
    1.0,                    # Probability of leaving a burst.
    \@CATID_PRICE_JOINT_NONBURST_DIST,
                            # Data distribution during non-burst times.
    \@CATID_PRICE_JOINT_BURST_DIST
                            # Data distribution during burst times.
);

# Parameters for the ClosedAuction table.
my @LL_CA_PARAMS =
(
    0.0,                    # Probability of entering a burst.
    1.0                     # Probability of leaving a burst.
);


# The ``overload'' case.
my @OL_R_PARAMS = 
(
    1.0,                    # Probability of entering a burst.
    0.0,                    # Probability of leaving a burst.
    $g_r_nonburst_dist,    # Data distribution during non-burst times.
    $g_r_burst_dist        # Data distribution during burst times.
);

my @OL_S_PARAMS = 
(
    1.0,                    # Probability of entering a burst.
    0.0,                    # Probability of leaving a burst.
    $g_s_nonburst_dist,             # Data distribution during non-burst times.
    $g_s_burst_dist              # Data distribution during burst times.
);

my @OL_T_PARAMS = 
(
    1.0,                    # Probability of entering a burst.
    0.0,                    # Probability of leaving a burst.
    $g_t_dist,             # Data distribution during non-burst times.
    $g_t_dist              # Data distribution during burst times.
);

my @OL_U_PARAMS = 
(
    1.0,                    # Probability of entering a burst.
    0.0,                    # Probability of leaving a burst.
    $g_u_dist,             # Data distribution during non-burst times.
    $g_u_dist              # Data distribution during burst times.
);


my @OL_ITEM_FCP_PARAMS =
(
    1.0,                    # Probability of entering a burst.
    0.0,                    # Probability of leaving a burst.
    \@CATID_PRICE_JOINT_NONBURST_DIST,
                            # Data distribution during non-burst times.
    \@CATID_PRICE_JOINT_NONBURST_DIST,
                            # Data distribution during burst times.
);

my @OL_CA_PARAMS =
(
    1.0,                    # Probability of entering a burst.
    0.0                     # Probability of leaving a burst.
);


# The ``bursty correlated'' case.
my @BC_R_PARAMS = 
(
    get_enter_burst_prob($R_BURST_PROB, $R_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($R_BURST_PROB, $R_BURST_LEN),
                            # Probability of ending a burst.
    $g_r_nonburst_dist,    # Data distribution during non-burst times.
    $g_r_burst_dist     # Data distribution during burst times.
);

my @BC_S_PARAMS = 
(
    get_enter_burst_prob($S_BURST_PROB, $S_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($S_BURST_PROB, $S_BURST_LEN),
                            # Probability of ending a burst.
    $g_s_nonburst_dist,             # Data distribution during non-burst times.
    $g_s_burst_dist              # Data distribution during burst times.
);



my @BC_T_PARAMS = 
(
    get_enter_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of ending a burst.
    $g_t_dist,             # Data distribution during non-burst times.
    $g_t_dist              # Data distribution during burst times.
);

my @BC_U_PARAMS = 
(
    get_enter_burst_prob($U_BURST_PROB, $U_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($U_BURST_PROB, $U_BURST_LEN),
                            # Probability of ending a burst.
    $g_u_dist,             # Data distribution during non-burst times.
    $g_u_dist              # Data distribution during burst times.
);



my @BC_ITEM_FCP_PARAMS =
(
    get_enter_burst_prob($FCP_BURST_PROB, $FCP_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($FCP_BURST_PROB, $FCP_BURST_LEN),
                            # Probability of ending a burst.
    \@CATID_PRICE_JOINT_NONBURST_DIST,
                            # Data distribution during non-burst times.
    \@CATID_PRICE_JOINT_NONBURST_DIST
                            # Data distribution during burst times.
);

my @BC_CA_PARAMS =
(
    get_enter_burst_prob($CA_BURST_PROB, $CA_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($CA_BURST_PROB, $CA_BURST_LEN)
                            # Probability of ending a burst.
);



# The ``bursty independent'' case.
my @BI_R_PARAMS = 
(
    get_enter_burst_prob($R_BURST_PROB, $R_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($R_BURST_PROB, $R_BURST_LEN),
                            # Probability of ending a burst.
    $g_r_nonburst_dist,    # Data distribution during non-burst times.
    $g_r_burst_dist        # Data distribution during burst times.
);

my @BI_S_PARAMS = 
(
    get_enter_burst_prob($S_BURST_PROB, $S_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($S_BURST_PROB, $S_BURST_LEN),
                            # Probability of ending a burst.
    $g_s_nonburst_dist,             # Data distribution during non-burst times.
    $g_s_burst_dist              # Data distribution during burst times.
);

my @BI_T_PARAMS = 
(
    get_enter_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of ending a burst.
    $g_t_dist,             # Data distribution during non-burst times.
    $g_t_dist              # Data distribution during burst times.
);

my @BI_U_PARAMS = 
(
    get_enter_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($T_BURST_PROB, $T_BURST_LEN),
                            # Probability of ending a burst.
    $g_u_dist,             # Data distribution during non-burst times.
    $g_u_dist              # Data distribution during burst times.
);


my @BI_ITEM_FCP_PARAMS =
(
    get_enter_burst_prob($FCP_BURST_PROB, $FCP_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($FCP_BURST_PROB, $FCP_BURST_LEN),
                            # Probability of ending a burst.
    \@CATID_PRICE_JOINT_NONBURST_DIST,
                            # Data distribution during non-burst times.
    \@CATID_PRICE_JOINT_BURST_DIST
                            # Data distribution during burst times.
);

my @BI_CA_PARAMS =
(
    get_enter_burst_prob($CA_BURST_PROB, $CA_BURST_LEN),
                            # Probability of entering a burst.
    get_exit_burst_prob($CA_BURST_PROB, $CA_BURST_LEN)
                            # Probability of ending a burst.
);


#
# TABLE PARAMETERS 
# (Used as arguments to load_tables().)
#

# An array of table names; the index into this array is used to decode the
# arrays that follow.
my @TABLE_NAMES = ("R_source", "S_source", "T_source", "U_source",
                    "ClosedAuction", "FakeCurrentPrice", "Item");
my @MODE_NAMES = ("LL","OL","BC","BI");

# Basic parameters for each relation.
# Format: (table name, num cols, num tuples, time between burst tuples,
#           time between nonburst tuples).
my @R_TAB_BASICS = ("R_source", 1, $NUM_R_TUPLES, $R_BURST_RATE, $R_NONBURST_RATE);
my @S_TAB_BASICS = ("S_source", 2, $NUM_S_TUPLES, $S_BURST_RATE, $S_NONBURST_RATE);
my @T_TAB_BASICS = ("T_source", 1, $NUM_T_TUPLES, $T_BURST_RATE, $T_NONBURST_RATE);
my @U_TAB_BASICS = ("U_source", 2, $NUM_U_TUPLES, $U_BURST_RATE, $U_NONBURST_RATE);
my @CA_TAB_BASICS = ("ClosedAuction", 3, $NUM_CA_TUPLES, $CA_BURST_RATE, 
                    $CA_NONBURST_RATE);
my @FCP_TAB_BASICS = ("FakeCurrentPrice", 2, $NUM_FCP_TUPLES, $FCP_BURST_RATE, 
                    $FCP_NONBURST_RATE);
my @ITEM_TAB_BASICS = ("Item", 5, $NUM_ITEM_TUPLES, $ITEM_BURST_RATE, 
                    $ITEM_NONBURST_RATE);

my @TAB_BASICS = (\@R_TAB_BASICS, \@S_TAB_BASICS, \@T_TAB_BASICS, 
                    \@U_TAB_BASICS,
                    \@CA_TAB_BASICS, \@FCP_TAB_BASICS, \@ITEM_TAB_BASICS);


# Parameters for each of the modes for each relation.
my @R_MODE_PARAMS = 
    (\@LL_R_PARAMS, \@OL_R_PARAMS, \@BC_R_PARAMS, \@BI_R_PARAMS);
my @S_MODE_PARAMS = 
    (\@LL_S_PARAMS, \@OL_S_PARAMS, \@BC_S_PARAMS, \@BI_S_PARAMS);
my @T_MODE_PARAMS = 
    (\@LL_T_PARAMS, \@OL_T_PARAMS, \@BC_T_PARAMS, \@BI_T_PARAMS);
my @U_MODE_PARAMS = 
    (\@LL_U_PARAMS, \@OL_U_PARAMS, \@BC_U_PARAMS, \@BI_U_PARAMS);

my @ITEM_FCP_MODE_PARAMS =
    (\@LL_ITEM_FCP_PARAMS, \@OL_ITEM_FCP_PARAMS, \@BC_ITEM_FCP_PARAMS,
        \@BI_ITEM_FCP_PARAMS);
my @CA_MODE_PARAMS =
    (\@LL_CA_PARAMS, \@OL_CA_PARAMS, \@BC_CA_PARAMS,
        \@BI_CA_PARAMS);


my @TABLE_MODES = (\@R_MODE_PARAMS, \@S_MODE_PARAMS, \@T_MODE_PARAMS,
        \@U_MODE_PARAMS,
        \@CA_MODE_PARAMS, \@ITEM_FCP_MODE_PARAMS, \@ITEM_FCP_MODE_PARAMS);


#
# Subroutines for accessing different table parameters.
#

sub get_basic_param($$) {
    my ($tabname, $index) = @_;
    my $params_index = get_table_names_index($tabname);
    my $basics_ref = $TAB_BASICS[$params_index];

    return $basics_ref->[$index];
}

sub get_mode_params($$) {
    my ($tabname, $mode) = @_;
    my $params_index = get_table_names_index($tabname);
    my $params_list_ref = $TABLE_MODES[$params_index];
    my $mode_index = get_mode_names_index($mode);
    my $mode_params_ref = $params_list_ref->[$mode_index];
}


# How many columns in a table?
sub get_num_columns($) {
    my ($tabname) = @_;
    return get_basic_param($tabname, 1);
}

# How many tuples to load in this table?
# Second argument is a scaling factor.
sub get_num_to_load($$) {
    my ($tabname, $scaling_factor) = @_;
    return int($scaling_factor * get_basic_param($tabname, 2));
}

# Second argument of get_[non]burst_rate() is the length of a time unit, in
# usec.
sub get_burst_rate($$) {
    my ($tabname, $time_unit) = @_;
    return $time_unit * get_basic_param($tabname, 3);
}

sub get_nonburst_rate($$) {
    my ($tabname, $time_unit) = @_;
    return $time_unit * get_basic_param($tabname, 4);
}


# Data distribution during burst...
sub get_burst_dist($$) {
    my ($tabname, $mode) = @_;
    my $mode_params_ref = get_mode_params($tabname, $mode);

    my $dist_ref = $mode_params_ref->[3];
    return $dist_ref;
}


# ...and during nonburst.
sub get_nonburst_dist($$) {
    my ($tabname, $mode) = @_;
    my $mode_params_ref = get_mode_params($tabname, $mode);

    my $dist_ref = $mode_params_ref->[2];
    return $dist_ref;
}

sub get_burst_enter_prob($$) {
    my ($tabname, $mode) = @_;
    my $mode_params_ref = get_mode_params($tabname, $mode);

    my $dist_ref = $mode_params_ref->[0];
    return $dist_ref;
}

sub get_burst_exit_prob($$) {
    my ($tabname, $mode) = @_;
    my $mode_params_ref = get_mode_params($tabname, $mode);

    my $dist_ref = $mode_params_ref->[1];
    return $dist_ref;
}


#
# GLOBALS
#

# The current experiment mode.
#my $g_current_mode;

# A hash table of open temp files for different tables.
my %g_table_tmp_files;

# Lists that simulate the input queues for each of the streams.
my %g_do_input_queues;
my %g_sn_input_queues;

# Are we currently processing a tuple?
my $g_do_is_working;
my $g_sn_is_working;

# How many values we've read from each table.
my %g_num_tuples_loaded;

# Is this stream in a burst?
my %g_stream_is_in_burst;

# A buffer for holding information about items in the Auction schema.
# Each entry is keyed by itemid and holds the categoryID for that item.
#
# Entries are put into place by the code that creates FakeCurrentPrice tuples
# and consumed by the code that creates Item tuples.
my %g_item_catid_buf;


# A set of buffers for holding information about tuples whose data generation
# we have deferred (usually to model correlations with tuples that are yet to
# come).
#
# Each entry is a reference to a hashtable.
my %g_pending_tuple_drop_values;

#sub set_pending_tuple_drop_values($tabname, $tupnum, $is_dropped_do,
#        $is_dropped_sn) 
sub set_pending_tuple_drop_values($$$$) 
{
    my ($tabname, $tupnum, $is_dropped_do, $is_dropped_sn) = @_;

#    print 
#    "Putting pending drop values in place for tuple $tupnum of $tabname\n";

    my @list = ($is_dropped_do, $is_dropped_sn);
    $g_pending_tuple_drop_values{$tabname}->{$tupnum} = \@list;

}

my $g_module_is_initialized = 0;



# SUBROUTINES

# SUBROUTINE init
#
# Initializes the module's data structures.
sub init() {

#    print STDERR "Initializing load module...\n";

    # Generate distributions.

    # R doesn't change during bursts.
    $g_r_burst_dist->gaussian([$NUM_RST_COL_VALS], $NUM_RST_COL_VALS / 2);
    $g_r_nonburst_dist->gaussian([0], $NUM_RST_COL_VALS / 2);
    
    # S does change during bursts.
    $g_s_nonburst_dist->gaussian([$NUM_RST_COL_VALS/4, $NUM_RST_COL_VALS/4], 
                    $NUM_RST_COL_VALS / 4);
    $g_s_burst_dist->gaussian([3 * $NUM_RST_COL_VALS/4, 
                                3 * $NUM_RST_COL_VALS/4], 
                    $NUM_RST_COL_VALS / 4);
    
    # t doesn't change either
    $g_t_dist->uniform();

    # U is another distribution.
#    $g_u_dist->city([$NUM_RST_COL_VALS/4, $NUM_RST_COL_VALS/4], 0);
    $g_u_dist->gaussian([$NUM_RST_COL_VALS/4, $NUM_RST_COL_VALS/4], 
                        $NUM_RST_COL_VALS / 4);

    # Insert additional initialization code here...

    $g_module_is_initialized = 1;
}

# SUBROUTINE get_mode_index
#
# Returns the index (in @MODE_NAMES) of the indicated mode.
#sub get_mode_index($modename) {
sub get_mode_index($) {
    my ($modename) = @_;
    for (my $i = 0; $i < (scalar @MODE_NAMES); $i++) {
        if ($MODE_NAMES[$i] eq $modename) {
            return $i;
        }
    }

    die "Invalid mode name $modename.\n";
}

# SUBROUTINE get_enter_burst_prob, get_exit_burst_prob
#
# Returns the probability of starting or ending a burst.
#
# Arguments:
#       <burstprob> is the probability that a _given_ tuple is in a burst.
#       <ex_burst_len> is the expected length of a burst.
#sub get_enter_burst_prob($burstprob, $ex_burst_len) {
sub get_enter_burst_prob($$) {
    my ($burstprob, $ex_burst_len) = @_;

    # The number of burst periods is equal to the number of nonburst periods,
    # so we have:
    #   P[Tuple in burst] = E[length of burst] 
    #                       / (E[length of burst] + E[length of nonburst])
    #
    # Thus:
    #   E[length of nonburst] = ((1 - P[...]) / P[...]) * E[length of burst]
    #
    # So:
    #   P[enter burst] = 1 / E[length of nonburst] 
    #           = P[...] / (E[length of burst] * (1 - P[...]))

    return ($burstprob / ($ex_burst_len * (1 - $burstprob)));
}

sub get_exit_burst_prob($$) {
    my ($burstprob, $ex_burst_len) = @_;

    # E[length of burst] = 1 / (P[leave burst]), so
    # P[leave burst] = 1 / E[length of burst].

    return 1 / $ex_burst_len;
}

# Forward declaration of dist_sum() subroutine...
sub dist_sum($$);

# SUBROUTINE dist_sum
#
# Returns the sum of all the constants in a distribution.
#
# Arguments: 
#	<dist> is a reference to a distribution with <numdims> dimensions.
#sub dist_sum($dist, $numdims) {
sub dist_sum($$) {
    my ($dist, $numdims) = @_;

    my $dist_list_ref = $dist;

    my $total_sum = 0;

    if (1 == $numdims) {
	# Base case: 1-dimensional distribution.
	foreach my $list (@$dist_list_ref) {
	    $total_sum += $list->[0];
	}

	return $total_sum;

    } else {
	# Inductive case: Multidimensinal distribution.
	foreach my $list (@$dist_list_ref) {
	    my $local_weight = $list->[0];
	    $total_sum += $local_weight * dist_sum($list->[1], $numdims - 1);
	}

	return $total_sum
    }
}

# SUBROUTINE get_random_tuple
#
# Returns a random member of the indicated distribution.
#
# Arguments: 
#	<dist> is a reference to a distribution with <numdims> dimensions.
#sub get_random_addr($dist, $numdims) {
sub get_random_tuple($$) {
    my ($dist, $numdims) = @_;

    my $dist_list_ref = $dist;
    my @result;

DIM: 
    for (my $dim = 0; $dim < $numdims; $dim++) {
	# Find the sum of the elements in the distribution along this
	# dimension.
	my $dist_sum = 0;	
	foreach my $list (@$dist_list_ref) {
	    $dist_sum += $list->[0];
	}

	# Choose a random number along this dimension.
	my $rand_num = rand $dist_sum;

	# Figure out which element that corresponds to, and go there.
	my $skipped_sum = 0;
	for (my $i = 0; $i < (scalar @$dist_list_ref); $i++) {
	    $skipped_sum += $dist_list_ref->[$i][0];


	    if ($skipped_sum > $rand_num) {

		# Found the element...
		push @result, ($i + 1);

		$dist_list_ref = $dist_list_ref->[$i][1];
		next DIM;
	    }
	}
    }

    return \@result;
}

# SUBROUTINE load_cat
#
# Loads the Category table of the auction schema.
#
# Arguments: <dbname> is the name of the demo database.
#       <mode> is the mode in which to run the experiment.
#sub load_cat($dbname, $mode) {
sub load_cat($$) {
    my ($dbname, $mode) = @_;
                                                                                 
    # Mode argument is ignored for now.
                                                                                 
    # We need to manage the creation of categories carefully, so we load the
    # table "by hand" here.
#    print "    Loading Category table...\n";
                                                                                 
    # Generate a comma-delimited text file
    open TMP, "> $DATA_TMP_FILE" or die "Couldn't open temp file.\n";
                                                                                 
    for (my $i = 1; $i <= $NUM_CATEGORIES; $i++) {
        print TMP "$i,Category $i,Category $i\n";
    }
                                                                                 
    close TMP;
                                                                                 
    # Generate a file of commands to feed into psql.
    open CTMP, "> $CMD_TMP_FILE";
    print CTMP "COPY Category FROM '$DATA_TMP_FILE' WITH DELIMITER AS ',';\n";
    close CTMP;
                                                                                 
    # Run the commands we just echoed to the file.
    system "psql --quiet -d $dbname -f $CMD_TMP_FILE";
}


# SUBROUTINE load_simple
#
# Uses the event loop to load the "simple" schema.
#
# Arguments:
#       <dbname> is the name of the demo database.
#       <mode> is the mode in which to run the experiment, and should be one
#           of the following:
#               "LL" for low load.
#               "OL" for overload.
#               "BC" for bursty correlated.
#               "BI" for bursty independent.
#       <time_unit> is the length of one "unit" of time, in microseconds.
#       <scaling_factor> is a factor by which to multiply the size of each
#               table.
#sub load_simple($dbname, $mode, $time_unit, $scaling_factor) {
sub load_simple($$$$) {
    my ($dbname, $mode, $time_unit, $scaling_factor) = @_;

    print STDERR "    Loading simple schema for mode $mode.\n";

    my @TABNAMES = ("R_source", "S_source", "T_source", "U_source");
        # Tables in this schema.

    load_tables($dbname, $mode, \@TABNAMES, $time_unit, $scaling_factor);

    # We also need to load the A_values table.
    my $filename = tmp_file_name("A_values"); 
    open AVALS, "> $filename" or die "Couldn't open file $filename";
    for (my $i = 0; $i < $NUM_RST_COL_VALS; $i++) {
        print AVALS "$i\n";
    }
    close AVALS;

    open CTMP, "> $CMD_TMP_FILE";
    print CTMP "COPY A_values FROM '$filename' WITH DELIMITER AS ',';\n";
    close CTMP;

    system "psql --quiet -d $dbname -f $CMD_TMP_FILE";



}

# SUBROUTINE load_auction
#
# Uses the event loop to load the "auction" schema.
#
# Arguments:
#       <dbname> is the name of the demo database.
#       <mode> is the mode in which to run the experiment, and should be one
#           of the following:
#               "LL" for low load.
#               "OL" for overload.
#               "BC" for bursty correlated.
#               "BI" for bursty independent.
#       <time_unit> is the length of one "unit" of time, in microseconds.
#       <scaling_factor> is a factor by which to multiply the size of each
#               table.
#
#sub load_auction($dbname, $mode, $scaling_factor) {
sub load_auction($$$) {
    my ($dbname, $mode, $time_unit, $scaling_factor) = @_;

    print STDERR "    Loading auction schema for mode $mode.\n";

    # First we load up the Category table.
    load_cat($dbname, $mode);

    my @TABNAMES = ("ClosedAuction", "Item", "FakeCurrentPrice");
        # Tables in this schema.

    # Initialize the data structure that tells whether

    load_tables($dbname, $mode, \@TABNAMES, $time_unit, $scaling_factor);

}


# SUBROUTINE load_tables
#
# Uses the event loop to load several "stream" tables at once.
#
# Arguments:
#       <dbname> is the name of the demo database.
#       <mode> is the mode in which to run the experiment, and should be one
#           of the following:
#               "LL" for low load.
#               "OL" for overload.
#               "BC" for bursty correlated.
#               "BI" for bursty independent.
#       <tabnames> is a reference to a list of the names of the tables to load.
#       <time_unit> is the length of a single unit of time, in usec.
#       <scaling_factor> is multiplied by the weight of each table to
#           determine the number of tuples to load into the table.
#
#sub load_tables($dbname, $mode, $tabnames, $time_unit, $scaling_factor) {
sub load_tables($$$$$) {
    my ($dbname, $mode, $tabnames, $time_unit, $scaling_factor) = @_;

    # Initialize globals if necessary.
    if (0 == $g_module_is_initialized) {
        init();
    }

    # Open up the temp files that hold the table contents. 
    foreach my $tabname (@$tabnames) {
        my $filename = tmp_file_name($tabname);

        local *HANDLE;
        open HANDLE, "> $filename" or die "Couldn't open file $filename";

        $g_table_tmp_files{$tabname} = *HANDLE;
    }

    # Generate the tuples of each table.
    foreach my $tabname (@$tabnames) {
        my $num_to_load = get_num_to_load($tabname, $scaling_factor);

        # Initialize the status of this table.
        $g_stream_is_in_burst{$tabname} = 0;

        my $last_arrival_time = $INITIAL_DELAY_USEC;
            # In microseconds.

        for ($g_num_tuples_loaded{$tabname} = 0; 
            $g_num_tuples_loaded{$tabname} < $num_to_load; 
            $g_num_tuples_loaded{$tabname}++) {
            
#            printf STDERR "Loading tuple %d of %d for table %s.\n",
#                $g_num_tuples_loaded{$tabname}, $num_to_load,
#                $tabname;
            
            # Figure out what time this tuple arrives at.
            update_in_burst($tabname, $mode);
            my $interval = 
                    $g_stream_is_in_burst{$tabname} ?
                        get_burst_rate($tabname, $time_unit)
                        : get_nonburst_rate($tabname, $time_unit);


            my $tup = get_next_tuple($tabname, $mode);

            # Write the tuple to the appropriate file.
            my $fh = $g_table_tmp_files{$tabname};

            my $rounded_arrival_time = int($last_arrival_time);

            print $fh "$rounded_arrival_time,";
            print $fh join ",", @$tup;
            print $fh "\n";

            $last_arrival_time += $interval;
        }
    }

    # Load the temp files into the database.
    foreach my $tabname (@$tabnames) {
        my $fh = $g_table_tmp_files{$tabname};
        close $fh;

        # Generate a file of commands to feed into psql.
        open CTMP, "> $CMD_TMP_FILE";
        print CTMP "COPY $tabname FROM '" . tmp_file_name($tabname)
            . "' WITH DELIMITER AS ',';\n";
        close CTMP;

        # Run the commands we just echoed to the file.
        system "psql --quiet -d $dbname -f $CMD_TMP_FILE";

    }
}




sub get_queue_is_full($$) {
    my ($type, $tabname) = @_;

    my $q_ref;
    if ($type eq "do") {
        $q_ref = $g_do_input_queues{$tabname};
    } else {
        $q_ref = $g_sn_input_queues{$tabname};
    }

    my $q_len = scalar @$q_ref;

    if ($q_len >= $STREAM_Q_LEN) {
        return 1;
    } else {
        return 0;
    }
}

sub push_tuple_on_q($$$) {
    my ($type, $tabname, $tup_ref) = @_;
    
    my $q_ref;
    if ($type eq "do") {
        $q_ref = $g_do_input_queues{$tabname};
    } else {
        $q_ref = $g_sn_input_queues{$tabname};
    }

    push @$q_ref, $tup_ref;

    if ($type eq "do") {
        if (0 == $g_do_is_working) {
            handle_do_queues($tabname);
        }
    } else {
        if (0 == $g_sn_is_working) {
            handle_sn_queues($tabname);
        }
    }
}




#sub get_next_tab($tabname) {
sub get_next_tab($$) {
    my ($tabname, $listref) = @_;

    my $lindex = -1;
    for (my $i = 0; $i < scalar @$listref; $i++) {
        if ($listref->[$i] eq $tabname) {
            $lindex = $i;
        }
    }
    die if (-1 == $lindex);

    # don't forget to wrap around!
    my $next_index = ($lindex + 1) % (scalar @$listref);

    return $listref->[$next_index];
 }


# SUBROUTINE get_next_tuple
#
# Generates the next tuple in the indicated table.
# Returns the tuple as an array reference.
#sub get_next_tuple($tabname, $mode) {
sub get_next_tuple($$) {

    my ($tabname, $mode) = @_;
    
    my $is_burst = $g_stream_is_in_burst{$tabname};

    my $numcols = get_num_columns($tabname);

    my $numloaded = $g_num_tuples_loaded{$tabname};

    # Get the current data distribution of this table.
    my $dist_ref;

    if (1 == $is_burst) {
#        print "Generating burst tuple.\n";
        $dist_ref = get_burst_dist($tabname, $mode);
    } else {
        $dist_ref = get_nonburst_dist($tabname, $mode);
    }

    # Generate the tuple...
    if ($tabname eq "ClosedAuction") {
        # ClosedAuction table.  Format of this table is:
        
#create table ClosedAuction(
#            itemID integer,    /* id of the item in this auction.Key attribute 
#                                  of this stream. References Item.id */
#            buyerID integer,   /* buyer of this item. References Person.id. 
#                                  Could be NULL if there was no buyer. */
#            timestamp integer, /* time when the auction closed */
#            is_dropped_do integer, is_dropped_sn integer); 

        my $itemID = $numloaded;
        
        # TODO: When we load the Person table, generate random buyerIDs here.
        my $buyerID = 1;

        my @vals = ($itemID, $buyerID, $itemID);

        return \@vals;
    } elsif ($tabname eq "FakeCurrentPrice") {
        # FakeCurrentPrice table.  Format of this table is:
        #
        #create table FakeCurrentPrice(
        #        itemID integer,
        #        price integer,
        #        is_dropped_do integer, is_dropped_sn integer); 

        # We need to keep the tuples of this table in sync with the Items
        # table; in particular, categoryID (stored in Item) and price (stored
        # in FakeCurrentPrice) are correlated, and their joint distribution
        # depends on whether the FakeCurrentPrice tuple is burst or non-burst.
        
        my $itemID = $numloaded;

        my $vals_ref = get_random_tuple($dist_ref, 2);
        my ($categoryID, $price) = @$vals_ref;

        add_item_catid_mapping("Item", $itemID, $categoryID);
            # This subroutine takes care of the Item side of things for us.

        my @vals = ($itemID, $price);

        return \@vals;

    } elsif ($tabname eq "Item") {
        # The Item table is special, because its values depend on the
        # FakeCurrentPrice table's values.  Before an Item tuple can be
        # generated, the corresponding FCP tuple needs to be created.  If the
        # FCP tuple has already been created, we spit out the Item tuple;
        # otherwise, we defer generation of the Item tuple.
        
        # Format of this table:
#create table Item(
#            id integer          /* unique identifier */,
#            name varchar        /* name of the item */,
#            description varchar /* description of the item */, 
#            categoryID integer  /* category that this item belongs to. 
#                                    References Category.id  */,
#            registrationTime integer,
#                                /* time when this item was registered */
#            is_dropped_do integer, is_dropped_sn integer); 

        my $itemID = $numloaded;
        
        my $categoryID = get_catid_for_item($itemID);
            # This subroutine also removes the item in question from the
            # buffer.

        if (defined $categoryID) {
            # FCP tuple already generated.
            
            my @vals = 
            (
                $itemID,
                "Item $itemID",
                "Description $itemID",
                $categoryID,
                $itemID
            );

            return \@vals;

        } else {
#            print "Don't have an FCP tuple yet for item $itemID.\n";
            
            # Don't have the FCP tuple yet.
            return $NOT_A_TUPLE;
        }
    } elsif ($tabname eq "A_values") {

        my @vals = ($numloaded);

        return \@vals;

    } else {
        # Default case: Generate random integers from the distribution.
#        print "Getting a random tuple for $tabname\n";
        return $dist_ref->get_random_tuple();
#        return get_random_tuple($dist_ref, $numcols);
    }
}


# SUBROUTINE get_table_names_index
#
# Searches the TABLE_NAMES array to determine the index of the indicated table
# in the params arrays.
#sub get_table_names_index($tabname) {
sub get_table_names_index($) {
    my ($tabname) = @_;

    for (my $i = 0; $i < (scalar @TABLE_NAMES); $i++) {
        if ($TABLE_NAMES[$i] eq $tabname) {
            return $i;
        }
    }
    die "Invalid table name $tabname.\n";
}

# Similar subroutine for modes.
#sub get_mode_names_index($modename) {
sub get_mode_names_index($) {
    my ($modename) = @_;

    for (my $i = 0; $i < (scalar @MODE_NAMES); $i++) {
        if ($MODE_NAMES[$i] eq $modename) {
            return $i;
        }
    }
    die "Invalid mode name $modename.\n";
}

# Subroutine to update the "in a burst" property of a table.
#sub update_in_burst($tabname, $mode) {
sub update_in_burst($$) {
    my ($tabname, $mode) = @_;


    my $burst_rand = rand 1.0;

    if (1 == $g_stream_is_in_burst{$tabname}) {
        if ($burst_rand < get_burst_exit_prob($tabname, $mode)) {
            $g_stream_is_in_burst{$tabname} = 0;
        }
    } else {
        if ($burst_rand < get_burst_enter_prob($tabname, $mode)) {
            $g_stream_is_in_burst{$tabname} = 1;
        }
    }
 
}

# SUBROUTINE add_item_catid_mapping()
#
# Takes a mapping from itemID to categoryID, as generated from the
# distribution over categoryID and price while creating a FakeCurrentPrice
# tuple.  If the indicated Item tuple is ready to go, outputs it to the temp
# file; otherwise, deferes creation of the tuple but remembers its values.
sub add_item_catid_mapping($$$) {
    my ($tabname, $itemID, $categoryID) = @_;



    # Do we already know whether this tuple was dropped?
    if (defined $g_pending_tuple_drop_values{$tabname}->{$itemID}) {
        # Can generate the tuple now.
        my $drop_vals_hash_ref = $g_pending_tuple_drop_values{$tabname};
        my $drop_vals_ref = $drop_vals_hash_ref->{$itemID};

        my ($is_dropped_do, $is_dropped_sn) = @$drop_vals_ref;

        my $fh = $g_table_tmp_files{"Item"};
        print $fh "$itemID,Item $itemID,Description $itemID,"
            . "$categoryID, $itemID, $is_dropped_do, $is_dropped_sn\n";

#        print "Writing item $itemID to the output file.\n";
 
    } else {
#        print "Don't have drop values for tuple $itemID of $tabname.\n";

        # Defer creation of the tuple to later.
        $g_item_catid_buf{$itemID} = $categoryID;
    }
}

sub get_catid_for_item($) {
    my ($itemID) = @_;
    my $entry = $g_item_catid_buf{$itemID};

    # Clean up after ourselves.
    $g_item_catid_buf{$itemID} = undef;

    return $entry;
}


# Voodoo to make the module compile.  
return 1;



