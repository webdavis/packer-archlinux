#!/usr/bin/env bash

# Exit immediately if a "simple" command, a "compound" command, a list, or the last
# command in a pipeline exits with a non-zero exit status.
set -e

# Treat unset variables as errors, exiting when detected.
set -u

# Setting hostname, locales, etc.
hostnamectl set-hostname 'archlinux'
localectl set-keymap 'us'
timedatectl set-ntp true

# Setting link to systemd-resolved.
ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf
