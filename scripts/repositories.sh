#!/usr/bin/bash

  if [[ "$(find /install_script/configs -name paru.conf)" ]]; then
    cp /install_script/configs/pacman_without_arch.conf /etc/pacman.conf
    pacman -Sy --noconfirm artix-keyring
    rm -r /etc/pacman.d/gnupg
    pacman-key --init 
    pacman-key --populate artix
    pacman-key --refresh-keys
    pacman -Sy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp /install_script/configs/pacman_with_arch.conf /etc/pacman.conf
    pacman -Sy
  else 
    cp configs/pacman_without_arch.conf /etc/pacman.conf
    pacman -Syy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp configs/pacman_with_arch.conf /etc/pacman.conf 
    pacman -Sy
  fi
