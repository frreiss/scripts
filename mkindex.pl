#!/usr/bin/perl

my $USAGE = <<END;
mkindex.pl

Given a list of JPEG files in the current directory, make a simple photo
album.  Output goes to ./index.html.

Usage: mkindex.pl <title> <file1> <file2> ... <filen>

Where:
      <title> is the page title
      <file1> ... <filen> are the JPEG files.
END

use strict;
use warnings;

my ($title, @files) = @ARGV;

die $USAGE unless defined $title;

# Create thumbnails.
my @thumbs;
foreach my $filename (@files) {
    # Make extensions lowercase while we're at it.
    if ($filename =~ /(.*)\.(JPG)/) {
        my $new_filename = "$1.jpg";
        system "mv $filename $new_filename\n";
        $filename = $new_filename;
    }

    if ($filename =~ /(.*)\.(jpg)/) {
        my $prefix = $1;
        my $suffix = $2;
        my $thumbname = "${prefix}_small.${suffix}";
        print "Converting $filename...\n";
        system "convert -resize 20% $filename $thumbname";
        push @thumbs, $thumbname;
        
    } else {
        die "error processing filename $filename";
    }
}

# Generate the HTML
my @lines;

for (my $i = 0; $i < (scalar @files); $i++) {
    my $file = $files[$i];
    my $thumb = $thumbs[$i];
    my $line = "<p><a href=$file><img src=$thumb></a>";

    push @lines, $line;
}

my $lines = join "\n", @lines;

my $output = <<END;

<html>

<head><title>$title</title></head>

<body>
<h1>$title</h1>
$lines
</body>
</html>

END

open OUT, ">index.html" or die "Couldn't open index.html for writing.";
print OUT $output;
close OUT;

