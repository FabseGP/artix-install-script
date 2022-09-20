#!/usr/bin/bash
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
    cd /install_script/packages || exit
    ALPH_mirrorlist="$(ls -- *alhp-mirrorlist-*)"
    ALPH_keyring="$(ls -- *alhp-keyring-*)"
    pacman -U --noconfirm $ALPH_mirrorlist $ALPH_keyring
    cp /install_script/configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  else 
    pacman -Syy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cp configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  fi

