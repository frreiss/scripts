#!/usr/bin/perl

################################################################################
# pretty_make.pl
# 
# A script that makes the output of "make" human-readable.
#
# Usage: Same as "make".
#
# Outputs a log file, "pm.log".
################################################################################

# Uncomment the following to disable ANSI color codes.
#$ENV{'ANSI_COLORS_DISABLED'} = 1;

use Term::ANSIColor;
use Cwd;

use strict;
use warnings;


# CONSTANTS
my $MAX_DIR_NAME_LEN = 25;

# Construct the arguments to make.
my $args = join ' ', @ARGV;

# We capture STDOUT from make.
my $commandline = "make $args";
#print colored "Running '$commandline'.\n", 'bold blue';
open MAKE, "$commandline 2>&1 |" or die "Couldn't start make!\n";

open LOGFILE, ">> pm.log";

# Counters.
my $directory_count = 0;
my $file_count = 0;
my $recurse_count = 0;
my $fileop_count = 0;

my $directory_level = 0;

my @directory_stack;
push @directory_stack, getcwd;
my $last_dir_output = "";

# Remember at what wall-clock time we started.
my $start_time = time;

# Subroutine to print our current status.
sub print_status() {
    my $current_time = time;
    my $elapsed_time = $current_time - $start_time;

    my $dir = truncate_dir_name($directory_stack[$#directory_stack], 
                                $MAX_DIR_NAME_LEN); 

    # Print out our status.
    my $status = sprintf 
                    "(%4d:%02d) make[%-${MAX_DIR_NAME_LEN}s]: "
                        . "%5d files, %4d dirs, %3d fileops",
                            int($elapsed_time / 60),
                            $elapsed_time % 60,
                            $dir,
                            $file_count,
                            $directory_count,
                            $fileop_count;
    print colored $status, 'bold';
    
    # Move the cursor back to the beginning of the line, and flush stdout.
    $| = 0;
    print "\r";
    $| = 1;
}


# Subroutine that takes a string in the form "///dir1/dir2/dir" and scrapes
# off the "dir1" part.
sub remove_one_dir($) {
    my ($str) = @_;


    if ($str =~ /^\/*[^\/]*$/ or $str =~ /^<top>$/) {
        # Can't strip off anything more.
        return $str;
    }

    $str =~ /(\/*)([^\/]*)(\/.*)/; 

    
    my $ret = $1 . $3;

#    print STDERR "remove_one_dir($str) returns '$ret'\n";
     
    return $ret;
}


# Subroutine to truncate a directory name.  Inserts ellipses at the beginning
# if necessary.
#sub truncate_dir_name($dirname, $len) {
sub truncate_dir_name($$) {
    my ($dirname, $len) = @_;

    # First we remove the root of the source tree.
    my $root = $directory_stack[0];

#    $dirname =~ s/$root/<top>/;

    if ($dirname =~ /^$root$/) {
        $dirname = "<top>";
    } elsif ($dirname =~ /($root\/)(.*)/) {
        $dirname = $2;
    }

    # Then we strip off the first dir as long as the string is too ong.
    while (length($dirname) > $len) {
        
        my $new_dirname = remove_one_dir($dirname);

        if (($new_dirname eq $dirname) and (length($dirname) > $len)) {
            # Couldn't strip anything else out, so truncate.
            # Leave space for ellipses!
            my $trunc_name = substr $dirname, (length($dirname) - $len + 3);
#           print "trncnam is '$trunc_name'\n";

            return "...$trunc_name";

        }

        $dirname = $new_dirname;
    }

    return $dirname;
    
    # Then we remove every directory name except for the last one, keeping
    # the slashes.
    if ($dirname =~ /(.*\/)([^\/]*)/) {
        my $subdirs = $1;
        my $topdir = $2;

        $subdirs =~ s/[^\/]//g;

        $dirname = $subdirs . $topdir;
    }

    if (length($dirname) < $len) {
        # Add spaces at the end to pad out to the appropriate length.
        my $num_to_add = $len - length($dirname);
        for (my $i = 0; $i < $num_to_add; $i++) {
            $dirname .= ' ';
        }
#        print "dirname is '$dirname'\n";
        return $dirname;
    } else {
        # Leave space for ellipses!
        my $trunc_name = substr $dirname, (length($dirname) - $len + 3);
#        print "trncnam is '$trunc_name'\n";

        return "...$trunc_name";
    }

}

my $line;
while ($line = <MAKE>) {
    print LOGFILE $line;

    chomp $line;

    my $command = $line;

    # Catch escaped carriage returns.
    while ($command =~ /\\$/) {
        print LOGFILE $line;

        $line = <MAKE>;
        chomp $line;
        $command .= "\n$line";
        # TODO: Check for failure of Make.
    }

    if ($command =~ /Entering directory `(.*)'/) {
        $directory_count++;
        $directory_level++;
        push @directory_stack, $1;
    } elsif ($command =~ /Leaving directory `(.*)'/) {
        pop @directory_stack;
        $directory_level--;
    } elsif ($command =~ /cc /
            || $command =~ /c\+\+ /
            || $command =~ /g\+\+ /
            || $command =~ /ld /
            || $command =~ /^\w*sed / 
            || $command =~ /ar / 
            || $command =~ /ranlib / 
            || $command =~ /\/bin\/sh / 
            || $command =~ /gzip /) {
        # Compiler execution.
        $file_count++;
    } elsif ($command =~ /rm /
            || $command =~ /ln /
            || $command =~ /chmod /
            || $command =~ /cp /
            || $command =~ /install /
            || $command =~ /install-sh /
            || $command =~ /mkdir /) {
        $fileop_count++;
    } elsif ($command =~ /^make /) {
        $recurse_count++;
    } elsif ($command =~ /Nothing to be done/
            || $command =~ /is up to date.$/
            || $command =~ /^for/)
    {
        # Do nothing. 
    } else {
        # If we don't understand a line, pass it through.

        # First clear the line.
        for (my $i = 0; $i < 80; $i++) {
            print ' ';
        }
        print "\r";

        # Next, print the current directory, if applicable.
        if ($directory_stack[$#directory_stack] ne $last_dir_output) {
            $last_dir_output = $directory_stack[$#directory_stack];
            print colored "In ${last_dir_output}:\n", 'bold';
        }

        chomp $command;

        # Color-code different types of message.
        if ($command =~ /^(.*:[0-9]*: warning:)(.*)/) {
            $command = (colored $1, 'bold red') . (colored $2, 'red');
        } elsif ($command =~ /^(.*:[0-9]*:)(.*)/) {
            $command = colored $command, 'bold red';
        } else {
            $command = colored $command, 'red';
        }

        print "$command\n";
    }

    
    # Repeatedly print status until we get the next line.
    my $nfound;
    my $timeleft;
    do {
        print_status();

        # Wait until make's STDOUT is readable.
        my ($rin, $win, $ein);
        $rin = $ein = '';
        vec($rin,fileno(MAKE),1) = 1;
        $ein = $rin;

        my $timeout = 1;
        ($nfound,$timeleft) = 
            select($rin, '', $ein, $timeout); 
    } while (0 == $nfound);

}

# Prevent our last status message from showing up 
print "\n";

close MAKE;

