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
    cd /install_script/packages || exit
    ALPH_mirrorlist="$(ls -- *alhp-mirrorlist-*)"
    ALPH_keyring="$(ls -- *alhp-keyring-*)"
    pacman -U --noconfirm $ALPH_mirrorlist $ALPH_keyring
    cd $BEGINNER_DIR
    cp /install_script/configs/pacman.conf /etc/pacman.conf
    cp /install_script/configs/alhp-mirrorlist /etc/pacman.d/alhp-mirrorlist
    chmod 644 /etc/pacman.d/alhp-mirrorlist
    pacman -Syy 
  else 
    pacman -Syy --noconfirm artix-archlinux-support
    pacman-key --init
    pacman-key --populate archlinux artix
    cd packages || exit
    ALPH_mirrorlist="$(ls -- *alhp-mirrorlist-*)"
    ALPH_keyring="$(ls -- *alhp-keyring-*)"
    pacman -U --noconfirm $ALPH_mirrorlist $ALPH_keyring
    cd $BEGINNER_DIR
    cp configs/alhp-mirrorlist /etc/pacman.d/alhp-mirrorlist
    chmod 644 /etc/pacman.d/alhp-mirrorlist
    cp configs/pacman.conf /etc/pacman.conf
    pacman -Syy 
  fi

