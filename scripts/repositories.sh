#!/usr/bin/bash

  cp configs/pacman2.conf /etc/pacman.conf
  pacman -Syy --noconfirm artix-archlinux-support
  pacman-key --init
  pacman-key --populate archlinux artix
  if [[ "$(find /install_script/configs -name pacman.conf)" ]]; then
    cp /install_script/configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  else
    cp configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  fi
