#!/usr/bin/bash

  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup 
  cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist-arch-backup
  rankmirrors /etc/pacman.d/mirrorlist-backup > /etc/pacman.d/mirrorlist 
  rankmirrors /etc/pacman.d/mirrorlist-arch-backup > /etc/pacman.d/mirrorlist-arch
  rm -rf /etc/pacman.d/{mirrorlist-backup,mirrorlist-arch-backup}
