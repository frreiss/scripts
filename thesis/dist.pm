
################################################################################
# dist.pm
#
# A perl "class" that holds a discretized random distribution.
#
# Usage: 
#
# my $d = new dist(ndims, nbuckets);
#
# $d->uniform();
#
# $d->city(\@center_pt, $is_inverse);
#
# $d->gaussian(\@center_pt, $width);
#
# my $tup_ref = $d->get_random_tuple();
################################################################################

use strict;
use warnings;

use Math::CDF;

package dist;

################################################################################
# CONSTRUCTOR
#
# Arguments:
#       <class> is passed by the Perl interpreter.
#       <ndims> is the number of dimensions in the distribution.
#       <nbuckets> is the number of buckets along each dimension.
################################################################################
#sub new($class, $ndims, $nbuckets) {
sub new($$$) {
    my ($class, @param) = @_;

    # Perl voodoo.  Apparently, this creates the class instance, while
    # allowing for inheritance.
    my $self = {};
    bless $self, ref($class) || $class;

    $self->_initialize(@param);

    return $self;
}

# The subroutine that actually does the initialization.
#sub _initialize($self, $ndims, $nbuckets) {
sub _initialize($$$$) {
    my ($self, $ndims, $nbuckets) = @_;

    $self->ndims($ndims);
    $self->nbuckets($nbuckets);

    my %hash;
    $self->table(\%hash);

    $self->logprogress(0);
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

sub ndims {  _genacc(@_, 'ndims'); }
sub nbuckets {  _genacc(@_, 'nbuckets'); }

# The distribution, stored as a hashtable
sub table {  _genacc(@_, 'table'); }

# The keys of the hashtable, sorted lexically.
sub sortedkeys {  _genacc(@_, 'sortedkeys'); }

# Marginal sums of the weights in the distribution, for fast random number
# generation.  Ordered the same ways as sortedkeys.
# Index i of this list contains the sum of the weights for items 0 through i
# of sortedkeys.
sub marginalsums {  _genacc(@_, 'marginalsums'); }

# Should we output progress messages to STDERR during long operations?
sub logprogress { _genacc(@_, 'logprogress'); }

################################################################################
# METHODS
################################################################################

# Dump the distribution.
sub dump_dist($) {
    my ($self) = @_;
    
    my $hash_ref = $self->table;


    foreach my $key (sort keys %$hash_ref) {
        my $val = $hash_ref->{$key};

        print "$key --> $val\n";
    }
}

# Draw an n-tuple at random from the distribution.
sub get_random_tuple($) {
    my ($self) = @_;
    
    my $hash_ref = $self->table;

    my $ms_ref = $self->marginalsums;
    my $sk_ref = $self->sortedkeys;

    # Choose a random sum and do a binary search to find the corresponging sum
    # in the marginal sum dist.
    my $max_ix = (scalar @$ms_ref) - 1;
    my $max_sum = $ms_ref->[$max_ix];


    my $sum = rand $max_sum;
    
#    print "Max index is $max_ix\n";
#    print "Sum is $sum out of $max_sum\n";

    # Binary search...
    my $begin = 0;
    my $end = (scalar @$ms_ref);
        # Range of candidate region.

    while ($end > $begin) {
        my $new_off = int(($begin + $end) / 2);

        my $val = $ms_ref->[$new_off];

#        print "Range is [$begin, $end]; new offset is $new_off\n";
#        print "   Val is $val; sum is $sum\n";

        if ($val < $sum) {
            # Center of our candidate region is too far to the left.
            $begin = $new_off + 1;
        } else {
            $end = $new_off;
        }
    }


    my $dims_list = $sk_ref->[$begin];
    my @result = split /, /, $dims_list;
    return \@result;

    # Shouldn't get here!
    die "Something went wrong";
}

# Create a uniform distribution.
my $UNIFORM_FUNC = sub {
    return 1;
};
sub uniform($) {
    my ($self) = @_;
    
    $self->make_dist($UNIFORM_FUNC);
}

# Create a distribution where each value is the "walking on city streets"
# distance from a given point.
my @g_city_base_pt;

sub city_func {
    my $inverse = shift @_;
    my $ndims = shift @_;
    my $nbuckets = shift @_;

    my @current_pt = @_;

    die "Incompatible points" unless
        (scalar @g_city_base_pt) == (scalar @current_pt);

    my $total_diff = 0;

    for (my $i = 0; $i < (scalar @g_city_base_pt); $i++) {
        $total_diff += abs($g_city_base_pt[$i] - $current_pt[$i]); 
    }

    if (1 == $inverse) {
        my $val = 150 - $total_diff;

        return ($val > 0) ? $val : 0;
    } else {
        return $total_diff;
    }
};

my $CITY_FUNC = sub {
    city_func(0, @_);
};

my $INV_CITY_FUNC = sub {
    city_func(1, @_);
};

# First arg (after $self) is a center point, and second argument is 0 for
# prob. to be proportional to distance and 1 for probability 
sub city($$$) {
    my ($self, $pt_ref, $inverse) = @_;

    @g_city_base_pt = @$pt_ref;

    if ($inverse) {
        $self->make_dist($INV_CITY_FUNC);
    } else {
        $self->make_dist($CITY_FUNC);
    }
}

# Create a n-variate gaussian distribution, centered at the indicated point.
my @g_gaussian_base_pt;
my $g_gaussian_mult;

my $GAUSSIAN_FUNC = sub {
    my $ndims = shift @_;
    my $nbuckets = shift @_;
    my @current_pt = @_;

    die "Incompatible points" unless
        (scalar @g_gaussian_base_pt) == (scalar @current_pt);


    my $accum = 1.0;
    
    # Go through the dimensions, figuring out how far from the center we are
    # along each dimension.
    for (my $i = 0; $i < (scalar @g_gaussian_base_pt); $i++) {
        my $dist = abs($g_gaussian_base_pt[$i] - $current_pt[$i]); 

        # What is the normal probability density along this dimension?
        my $lower = ($dist - 0.5) / $g_gaussian_mult;
        my $upper = ($dist + 0.5) / $g_gaussian_mult;

        my $lower_val = Math::CDF::pnorm($lower);
        my $upper_val = Math::CDF::pnorm($upper);

        my $density = $upper_val - $lower_val;

        $accum *= $density;
    }

    return $accum; 
};

# First arg (after $self) is a center point, and second argument is 
# the width of the distribution.
sub gaussian($$) {
    my ($self, $pt_ref, $width) = @_;

    @g_gaussian_base_pt = @$pt_ref;

    $g_gaussian_mult = $width;

    $self->make_dist($GAUSSIAN_FUNC);
}


################################################################################
# "PRIVATE" METHODS
################################################################################


# SUBROUTINE make_dist
# 
# Creates a distribution, using the "filler-inner" function you provide.
#
# The function should as arguments:
#       ($ndims, $nbuckets, @dimvals),
#
# Where: 
#       <ndims> and <nbuckets> are as with the constructor.
#       @dimvalues is a list (passed DIRECTLY) containing the current bucket
#               along each dimension.
#
# The function should return the weight for the indicated bucket.
#sub make_dist($self, $fn_ref) {
sub make_dist($$) {
    my ($self, $fn_ref) = @_;
    
    my @dimvals;
        # Our current location along each dimension.

    for (my $i = 0; $i < $self->ndims; $i++) {
        $dimvals[$i] = 0;
    }

    # Calculate how many buckets we're going to generate, for status purposes.
    my $num_done = 0;
    my $num_to_do = $self->nbuckets ** $self->ndims;
        # "**" is exponentiation in perl.
BUCKET:
    for (;;) {
        # Fill in the current bucket.
        my $val = $fn_ref->($self->ndims, $self->nbuckets, @dimvals);

        my $key = join ", ", @dimvals;

#        print "$key --> $val\n";

        my $hash_ref = $self->table;

        $hash_ref->{$key} = $val;

        # Progress indicator.
        if ($self->logprogress) {
            $num_done++;
            if (0 == $num_done % 1243 or $num_done == $num_to_do - 1) {
                select STDERR; $| = 0; select STDOUT;
                printf STDERR "\r%7d of %7d buckets", $num_done + 1, $num_to_do;
                select STDERR; $| = 1; select STDOUT;
                if ($num_done == $num_to_do - 1) {
                    print STDERR "\n";
                }
            }
        }

        if ($self->nbuckets - 1 == $dimvals[0]) {
            # Carry...
            my $dim_level = 0;
            while ($dimvals[$dim_level] == $self->nbuckets - 1) {
                
                $dimvals[$dim_level] = 0;
                $dim_level++;

                if ($dim_level >= $self->ndims) {
                    # Turned over.
                    last BUCKET;
                }
            }
            $dimvals[$dim_level]++;
        } else {
            $dimvals[0]++;
        }
    }

#    print STDERR "Calling make_tables\n";

    # Fill in the data structures that speed up random number generation.
    $self->make_tables;

#    print STDERR "End of make_dist\n";
}

# SUBROUTINE make_tables
#
# Makes the auxiliary lookup tables that we will use to generate random
# tuples.
sub make_tables($) {
    my ($self) = @_;

    my $hash_ref = $self->table;

    my @new_sorted_keys = sort keys %$hash_ref;

    $self->sortedkeys(\@new_sorted_keys);

    my @new_marg_sums;

    $new_marg_sums[0] = $hash_ref->{$new_sorted_keys[0]};

    for (my $i = 1; $i < (scalar @new_sorted_keys); $i++) {
        $new_marg_sums[$i] = $new_marg_sums[$i - 1] + 
            $hash_ref->{$new_sorted_keys[$i]};
#        print "Marginal sum $i is $new_marg_sums[$i]\n";
    }

    $self->marginalsums(\@new_marg_sums);

    my $ms_ref = $self->marginalsums;
    my $sk_ref = $self->sortedkeys;
    
    # Choose a random sum and do a binary search to find the corresponging sum
    # in the marginal sum dist.
    my $max_ix = (scalar @$ms_ref) - 1;
    my $max_sum = $ms_ref->[$max_ix];


    my $sum = rand $max_sum;
    

}

# Voodoo to make the module compile.  
return 1;

