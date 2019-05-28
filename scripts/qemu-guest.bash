#!/usr/bin/env bash

# Exit immediately if a "simple" command, a "compound" command, a list, or the last
# command in a pipeline exits with a non-zero exit status.
set -e

# Treat unset variables as errors, exiting when detected.
set -u

sudo pacman --sync --noconfirm linux-headers
sudo pacman --sync --noconfirm qemu-guest-agent
