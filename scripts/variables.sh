#!/usr/bin/bash

  # Drives and partitions + encryption
  BOOT_size="300"
  BOOT_label="BOOT"
  RAM_size="$(($(free -g | grep Mem: | awk '{print $2}') + 1))"
  SWAP_size="$((RAM_size * 1000))"
  SWAP_label="RAM_co"
  HOME_size="NOT CHOSEN"
  HOME_label="HOME"
  PRIMARY_size="∞"
  PRIMARY_label="PRIMARY"
  ENCRYPTION_passwd="NOT CHOSEN"

  # Locals
  TIMEZONE="Europe/Copenhagen"
  LANGUAGES_generate="da_DK.UTF-8 en_GB.UTF-8"
  LANGUAGE_system="en_GB.UTF-8"
  KEYMAP_system="dk-latin1"
  HOSTNAME_system="artix"

  # Users
  ROOT_username="root"
  ROOT_passwd="NOT CHOSEN"
  USERNAME="NOT CHOSEN"
  USER_passwd="NOT CHOSEN"

  # Miscellaneous
  BOOTLOADER_label="ARTIX_BOOT"
  PACKAGES_additional="NONE"
  POST_install_script="NOT CHOSEN"
  POST_install_script_name="NOT CHOSEN"
  mapfile -t DRIVES < <(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}')
  core_count=$(($(grep -c ^processor /proc/cpuinfo) / 2))
