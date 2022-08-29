#!/usr/bin/bash
  if [[ "$(find /install_script/configs -name pacman.conf)" ]]; then
    cp /install_script/configs/pacman2.conf /etc/pacman.conf
    pacman -Sy --noconfirm artix-keyring
    rm -rf /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate artix
    pacman-key --refresh-keys
  fi
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
