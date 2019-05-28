#!/usr/bin/env bash

# Exit immediately if a "simple" command, a "compound" command, a list, or the last
# command in a pipeline exits with a non-zero exit status.
set -e

# Treat unset variables as errors, exiting when detected.
set -u

# Write zeros to improve virtual disk compaction.
zerofile="$(/usr/bin/mktemp /zerofile.XXXXX)"
dd if=/dev/zero of="$zerofile" bs=1M || true
rm --force "$zerofile"
sync
