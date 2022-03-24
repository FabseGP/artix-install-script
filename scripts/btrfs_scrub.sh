#!/bin/sh
# Perform a btrfs scrub on the root filesystem
  btrfs scrub start -c 2 -n 7 /
