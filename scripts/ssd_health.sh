#!/bin/sh
# Perform a btrfs scrub on the root filesystem
  btrfs scrub start -c 2 -n 7 /

# Perform periodic trim
  /usr/bin/fstrim -av > /var/log/trim.log || true
