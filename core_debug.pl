#! /usr/bin/perl

################################################################################
# core_debug.pl
#
# A simple script that debugs the most recent core dump in the current
# directory.
################################################################################

use strict;
use warnings;

my $DEBUGGER = "gdb";


# First find the most recent core dump.
my @files = `ls`;

my $newest_core = "";
my $newest_ctime = -1;

foreach my $filename (@files) {
    chomp $filename;
    if ($filename eq "core" || $filename =~ /^core\.\d*$/) {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, 
            $mtime, $ctime, $blksize, $blocks) = stat $filename;

        print "Creation time of $filename is $ctime.\n";

        if ($newest_core eq "" || $ctime > $newest_ctime) {
            $newest_core = $filename;
            $newest_ctime = $ctime;
        }
    }
}


# At this point, $newest_core holds the name of the newest core file.  Figure
# out what executable it is.  The quick and dirty way to do this is to find
# the first string in the file that is not "CORE".
my @strings = `strings $newest_core`;

foreach my $str (@strings) {
    chomp $str;
    if ($str ne "CORE") {
        # Found the executable name!
        print "Running '$DEBUGGER $str $newest_core'...\n";
        system "$DEBUGGER $str $newest_core";
        exit 0;
    }
}

