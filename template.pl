#!/usr/bin/perl

################################################################################
#$RCSfile: template.pl,v $
#$Revision: 1.4 $
#$Date: 2005/02/23 23:33:09 $
################################################################################

################################################################################
# template.pl
#
# A script to generate an empty perl script in Fred's style.  Asks a few
# questions about the script, then generates the script skeleton.
################################################################################

use strict;
use warnings;

my $EDITOR = "gvim";

$|=0;
print "Enter script name: ";
my $scriptname = <>;
chomp $scriptname;

print "Enter arguments, separated by spaces:\n";
my $args = <>;
chomp $args;

my @args = split / /, $args;
my $nargs = (scalar @args);

my @usage_args;
my @usage_descr_skel;
my @args_vars;
foreach my $arg (@args) {
    push @usage_args, "<$arg>";

    print "Enter description of argument <$arg>: ";
    my $descr = <>;
    chomp $descr;

    push @usage_descr_skel, "        <$arg> is $descr";
    push @args_vars, "\$" . uc $arg;
}

my $usage_args = join ' ', @usage_args;
my $usage_descr_skel = join "\n", @usage_descr_skel;
my $args_vars = join ', ', @args_vars;

print "Enter a short description (one line):\n";
my $short_description = <>;
chomp $short_description;

# We define this here so that all our variables magically flow into place.
my $SCRIPT_TEMPLATE = <<END;
#!/usr/bin/perl

################################################################################
#\$RCSfile: template.pl,v \$
#\$Revision: 1.4 \$
#\$Date: 2005/02/23 23:33:09 \$
################################################################################

use strict;
use warnings;

################################################################################
my \$USAGE = <<USAGE_END;
$scriptname

$short_description

Usage:    $scriptname $usage_args

Where:
$usage_descr_skel
USAGE_END
################################################################################


################################################################################
# ARGUMENTS

if ($nargs != (scalar \@ARGV)) {
    die \$USAGE;
}

my ($args_vars) = \@ARGV;

################################################################################
# CONSTANTS

################################################################################
# GLOBALS

################################################################################
# SUBROUTINES


################################################################################
############################################################
########################################
####################
# BEGIN SCRIPT


END

open SCRIPT, ">$scriptname" or die "Couldn't open $scriptname for writing";
print SCRIPT $SCRIPT_TEMPLATE;
close SCRIPT;
chmod 0755, $scriptname;

system "$EDITOR $scriptname"



