#!/bin/sh

# Perform a btrfs scrub on the root filesystem
  btrfs scrub start -c 2 -n 4 /

# Perform a btrfs balance on the root filesystem
  btrfs balance start -dusage=10 -musage=5
  btrfs balance start -dusage=20 -musage=10