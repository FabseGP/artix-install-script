#!/bin/sh
# Perform periodic trim
  /usr/bin/fstrim -av > /var/log/trim.log || true
