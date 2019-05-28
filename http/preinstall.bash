#!/usr/bin/env bash

# Exit immediately on error, or when unset parameters are expanded.
set -eu

# This function kills the script when user interruptions are detected
interrupt()
{
    local code=$?
    trap '' EXIT
    exit $code
}

# Trap any user interruptions, such as Ctrl+c, calling interrupt() when they're caught.
trap interrupt INT
trap interrupt QUIT
trap interrupt TERM

if [[ -b /dev/vda ]]; then
    device='/dev/vda'
elif [[ -b /dev/sda ]]; then
    device='/dev/sda'
else
    exit 1
fi
export device

# Grub supports LVM so all partitions can reside in LVM.
parted --script --align optimal "$device" mklabel msdos mkpart primary 1MiB 100%
parted --script "$device" set 1 lvm on
pvcreate "${device}1"
vg='volgroup'
vgcreate "$vg" "${device}1"
memory="$(free | awk '/^Mem:/ { print $2 }')"
swap="$((memory * 2))"
lvcreate --size "${swap}K" "$vg" -n swap
lvcreate --extents 100%FREE "$vg" -n root
mkswap --check "/dev/${vg}/swap"
mkfs.ext4 "/dev/${vg}/root"

# Bootstrap the virtual environment.
mount "/dev/${vg}/root" /mnt
pacstrap /mnt base grub linux-lts sudo openssh polkit haveged

# Turn the swap on so that genfstab correctly creates the partition scheme. It's not
# needed after that, and therefore can be turned off.
swapon "/dev/${vg}/swap"
genfstab -U -p /mnt >> /mnt/etc/fstab
swapoff "/dev/${vg}/swap"

# The lvm build fails without this. See:
# https://wiki.archlinux.org/index.php/GRUB#Device_/dev/xxx_not_initialized_in_udev_database_even_after_waiting_10000000_microseconds
mkdir /mnt/hostlvm
mount --bind /run/lvm /mnt/hostlvm

# Run ./chroot.bash
arch-chroot /mnt /bin/bash
