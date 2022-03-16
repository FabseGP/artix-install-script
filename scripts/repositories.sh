#!/usr/bin/bash

  if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
    pacman -Sy --noconfirm --needed artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    if [[ "$(find /install_script/configs -name pacman.conf)" ]]; then
      cp /install_script/configs/pacman.conf /etc/pacman.conf
      pacman -Syy 
    else
      cp configs/pacman.conf /etc/pacman.conf
      pacman -Syy 
    fi
  fi
