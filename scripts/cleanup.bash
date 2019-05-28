#!/usr/bin/env bash

# Exit immediately if a "simple" command, a "compound" command, a list, or the last
# command in a pipeline exits with a non-zero exit status.
set -e

# Treat unset variables as errors, exiting when detected.
set -u

# The first "clean" removes packages that are no longer installed, and the second "clean"
# removes all files from pacman's cache.
sudo pacman --sync --clean --clean --noconfirm

# Remove machine-id to prevent the boxes from passing the same client-id to the local DHCP
# service.
rm /etc/machine-id

# Remove the pacman key ring for re-initialization.
rm -rf /etc/pacman.d/gnupg

# Remove the hostlvm directory where the isoarch's lvm directory was mounted.
sudo rmdir --verbose /hostlvm
