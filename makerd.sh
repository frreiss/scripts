#!/bin/sh

# makerd.sh
#
# Script that creates the initial ramdisk based on the
# contents of the current machine's hard disk.


# Make a backup of the ramdisk.
mv -f /boot/initrd.img.gz /boot/initrd.img.gz~

rm -rf /root/initrd 

# Create the ramdisk.  We create a file at /boot/initrd.img and mount it at
# /root/initrd.
mkdir /root/initrd

# Count here is the size of the ramdisk.  Make sure that this is in sync with the 
# ramdisk_size parameter in grub.conf on the hard drive.
dd if=/dev/zero of=/boot/initrd.img bs=1k count=128000
/sbin/mke2fs -i 1024 -b 1024 -m 5 -F -v /boot/initrd.img
mount /boot/initrd.img /root/initrd -t ext2 -o loop

# Create directories; some we copy over, some we leave empty.
cp -r /bin /root/initrd

# /boot is mounted off of NFS, so just create a directory.
mkdir /root/initrd/boot

mkdir /root/initrd/cdrom

# Coeus home directories are currently hard-mounted individually under
# /coeus/[username]
mkdir /root/initrd/coeus
mkdir /root/initrd/coeus/chungwu
mkdir /root/initrd/coeus/sailesh
mkdir /root/initrd/coeus/tcondie
mkdir /root/initrd/coeus/yangsta

# /db is a link to /project
ln -s /project /root/initrd/db

cp -r /dev /root/initrd
cp -r /etc /root/initrd
mkdir /root/initrd/floppy
cp -r /home /root/initrd
cp -r /lib /root/initrd
mkdir /root/initrd/local
mkdir /root/initrd/mnt
mkdir /root/initrd/oldroot
mkdir /root/initrd/opt
mkdir /root/initrd/proc
mkdir /root/initrd/project
mkdir /root/initrd/root
cp -r /sbin /root/initrd
mkdir /root/initrd/telegraph1
mkdir /root/initrd/tmp
mkdir /root/initrd/usr

# /var/cache, /var/lib/apt, and /var/lib/dpkg reside on the file server, 
# and we don't want to copy them over.
umount /var/cache
umount /var/lib/apt
umount /var/lib/dpkg
cp -r /var /root/initrd
mount /var/cache
mount /var/lib/apt
mount /var/lib/dpkg

# The mtab reflects our state when the system is fully booted; in particular,
# it may contain a reference to the root filesystem.  Clear the mtab out.
rm -f /root/initrd/etc/mtab
touch /root/initrd/etc/mtab

# Copy this script itself into the ramdisk.  Allows us to make future changes
# more easily if we lose telegraph8's disk.
cp -r /root/config /root/initrd/root

# Copy root's config files, too.
cp -f /root/.??* /root/initrd/root

################################################################################
# Misc. cleanup.

# /dev/null somehow gets the wrong permissions when we copy it over...
chmod 777 /root/initrd/dev/null

# Same with /dev/tty
chmod ag+w /root/initrd/dev/tty

# And /dev/pty*
chmod ag+w /root/initrd/dev/ptmx
chmod ag+w /root/initrd/dev/pty*

# We don't want the other machines thinking they're telegraph8, so remove
# information about dhcp leases.
rm -f /root/initrd/var/lib/dhcp/*.leases

# Don't need old logfiles from another machine.
rm -f /root/initrd/var/log/*[012345]*

################################################################################
# Prepare the ramdisk for booting.
du -s /root/initrd
umount /root/initrd
gzip /boot/initrd.img

rm -rf /root/initrd
