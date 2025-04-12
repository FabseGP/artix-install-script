#!/usr/bin/bash

  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-backup
  cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist-arch-backup
 # cp /etc/pacman.d/chaotic-mirrorlist /etc/pacman.d/chaotic-mirrorlist-backup
 # cp /etc/pacman.d/alhp-mirrorlist /etc/pacman.d/alhp-mirrorlist-backup
  rankmirrors /etc/pacman.d/mirrorlist-backup > /etc/pacman.d/mirrorlist
  rankmirrors /etc/pacman.d/mirrorlist-arch-backup > /etc/pacman.d/mirrorlist-arch
 # rankmirrors /etc/pacman.d/chaotic-mirrorlist-backup > /etc/pacman.d/chaotic-mirrorlist
 # rankmirrors /etc/pacman.d/alhp-mirrorlist-backup > /etc/pacman.d/alhp-mirrorlist
 # rm -rf /etc/pacman.d/{mirrorlist-backup,mirrorlist-arch-backup,chaotic-mirrorlist-backup,alhp-mirrorlist-backup}
 rm -rf /etc/pacman.d/{mirrorlist-backup,mirrorlist-arch-backup}
