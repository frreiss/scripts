#!/usr/bin/perl

################################################################################
# cvsrm.pl
#
# Script to recursively and permanently remove a directory or file from
# CVS.  Run from your local CVS copy.  
#
# NOTE: Requires the "Expect" package.
#
# NOTE: ALWAYS make a backup before using this script!!!
#
# NOTE: ALWAYS do a "cvs update" before using this script!!!
#
# Usage: cvsrm.pl <file or directory to remove>
################################################################################

use strict;
use warnings;

# Use expect for remote-controlling CVS commands.
use Expect;

# Readable output
use Term::ANSIColor;

################################################################################
# SUBROUTINES
################################################################################

# Print a message to stderr
sub statusMsg($) {
    my ($msg) = @_;

    print STDERR colored("$msg\n", 'bold red');
}

# Print a "minor" status message (e.g. status of a subpart of the script) 
# to stderr
sub minorStatusMsg($) {
    my ($msg) = @_;

    print STDERR colored("  --> $msg\n", 'bold red');
}

# Recursively delete a file or directory.
sub deleteTarget($$) {
    my ($target,$passwd) = @_;

    if (-d $target) {
        # Target is a directory
        deleteDir($target,$passwd);
    } elsif (-f $target) {
        # Target is a file
        deleteFile($target,$passwd);
    } else {
        die "Don't know how to delete '$target'";
    }
}

sub deleteFile($$) {
    my ($target,$passwd) = @_;

    statusMsg("Deleting file $target");

    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
       $atime,$mtime,$ctime,$blksize,$blocks)
           = stat($target);

    if (0 == $size) {
        # SPECIAL CASE: Zero-length file.  Make the file one byte, so that
        # future commands will work properly.
        statusMsg("File is zero bytes long; making its size nonzero.");
        system "echo 'x' > '$target'";
        runCVS("cvs commit -m 'making file one byte long' '$target'", $passwd);
        # END SPECIAL CASE
    }

    # Determine what is the latest version.
    my $TMPFILE = "/tmp/status.txt";
    runCVS("cvs status '$target' > $TMPFILE", $passwd);

    open TMP, "$TMPFILE";
    my $version;
    while (my $line = <TMP>) {
        chomp $line;
        if ($line =~ /Working revision:\s+([\d\.]+)/) {
            $version = $1;
        }
    }
    close TMP;

    if (defined $version) {
        minorStatusMsg("Latest version is $version.");

        # Truncate the file to zero bytes.
        minorStatusMsg("Truncating to zero bytes.");
        system "echo '' > $target";

        # Then commit the truncated file.
        minorStatusMsg("Committing truncated file.");
        runCVS("cvs commit -m 'File removed by cvsrm.pl' '$target'", $passwd);

        # Remove all history up to the latest version.
        minorStatusMsg("Removing history up to version $version, inclusive.");
        runCVS("cvs admin -o :$version '$target'", $passwd);
    } else {
        statusMsg("WARNING: No version info for $target");
    }

    # Remove the file.
    minorStatusMsg("Removing file.");
    system "rm '$target'";
    runCVS("cvs rm '$target'", $passwd);
}

sub deleteDir($$) {
    my ($target,$passwd) = @_;

    # Don't delete CVS metadata...
    if ($target =~ /\/CVS$/) {
        statusMsg("Skipping CVS dir $target");
        return;
    }
    
    # No infinite recursion
    if ($target =~ /\/\.\.?$/ ) {
        return;
    }

    # Go through the directory contents, deleting everything.
    opendir(DIR, $target) 
            or die "Couldn't open directory $target";

    my @toDelete;

    while (my $file = readdir(DIR)) {

        my $path = $target . "/" . $file;

        unshift @toDelete, $path;

        # Don't do the deletion now, since we have an open handle on the
        # directory.
#        deleteTarget($path,$passwd); 
    }

    closedir(DIR);

    # Now we can do the deletions we deferred above.
    foreach my $path (@toDelete) {
        deleteTarget($path,$passwd); 
    }

    # Now we can wipe out the directory.
    statusMsg("Deleting dir $target from local copy");

    runCVS("cvs commit -m 'Directory contents removed by cvsrm.pl' '$target'", 
            $passwd);
    runCVS("cvs update -P '$target'", $passwd);
}

# Run a CVS command with a password
sub runCVS($$) {
    my ($cmd,$passwd) = @_;

    # Echo the command in a way that we can tell it apart from the script's
    # other output.
    print STDERR colored("$cmd\n", 'dark red');
#    minorStatusMsg("Running CVS command: $cmd");
    
    # We need to remote-control the CVS command so that we can enter a
    # password.
    my $exp = Expect->spawn($cmd) 
        or die "Cannot spawn command '$cmd'";

    # Wait until the password prompt.
    $exp->expect(10, "password:");

    # Send the password string.
    $exp->send("$passwd\n");

    # Wait for the command complete.
    $exp->soft_close();
    
}

################################################################################
# BEGIN SCRIPT
################################################################################

# Read argument
die "Usage: cvsrm.pl <file or directory to remove>" 
    unless 1 == (scalar @ARGV);

my $target = $ARGV[0];

# Collect the user's cvs password, without echoing it to stdout
print "Please enter your CVS passsword: ";
system("stty -echo");
my $pass = <STDIN>;
chomp $pass;
system("stty echo");
print "\n";

#printf STDERR "Got password '%s'\n", $pass;

deleteTarget($target, $pass);

$pass = undef;

