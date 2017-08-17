#!/usr/bin/perl

# sethostname.pl
#
# A simple script to set the hostname based on the current DHCP-supplied
# hostname.
#
# Also fixes the domains in /etc/resolv.conf
#
# Intended for use on the telegraph cluster, which is running Debian.

# Make extra sure that dhclient has been run by running it again.
system "/sbin/dhclient";

# Read the DHCP lease file.
open LEASES, "/var/lib/dhcp/dhclient.leases" 
    or die "Couldn't open leases file";

while (<LEASES>) {
    my $line = $_;
    if ($line =~ /option host-name \"(.*)\.[cC][sS]\.[bB]erkeley.[eE][dD][uU]/
        or 
        $line =~ /option host-name \"(.*)\.[cC][sS]\.[bB]erkeley.[eE][dD][uU]/)
    {
        my $new_hostname = $1;
        print STDERR "Using DHCP-provided hostname $new_hostname.\n";

        system "/bin/hostname $new_hostname";

        # Update /etc/hosts to reflect the new hostname.
        open HOSTS, "/etc/hosts" or die "Couldn't open /etc/hosts";
        my @hosts = <HOSTS>;
        close HOSTS;

        open HOSTS, ">/etc/hosts" 
            or die "Couldn't open /etc/hosts for writing.";
        foreach $line (@hosts) {
            if ($line =~ /^127\.0\.0\.1/) {
                print HOSTS "127.0.0.1\t$new_hostname\tlocalhost\n";
            } else {
                print HOSTS $line;
            }
        }
    }
}
close LEASES;

# Fix up resolv.conf, adding CS.berkeley.EDU to our list of domains to search.
open OLDRESOLV, "/etc/resolv.conf" or die "Couldn't open resolv.conf";
open NEWRESOLV, "> /etc/resolv.conf.new" 
    or die "Couldn't create new resolv.conf";

while (<OLDRESOLV>) {
    my $line = $_;
    if ($line =~ /search EECS.[Bb]erkeley.EDU/) {
        print NEWRESOLV "search EECS.berkeley.EDU CS.berkeley.EDU\n";
    } else {
        print NEWRESOLV $line;
    }
}
close NEWRESOLV;
close OLDRESOLV;

system "mv /etc/resolv.conf /etc/resolv.conf~";
system "mv /etc/resolv.conf.new /etc/resolv.conf";


