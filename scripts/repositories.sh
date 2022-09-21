#!/usr/bin/bash
  BEGINNER_DIR=$(pwd)
  if [[ "$(find /install_script/configs -name pacman.conf)" ]]; then
    cp /install_script/configs/pacman2.conf /etc/pacman.conf
    pacman -Sy --noconfirm artix-keyring
    rm -r /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate artix
    pacman-key --refresh-keys
    pacman -Sy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp /install_script/configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  else 
    pacman -Syy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  fi
