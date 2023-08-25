#!/usr/bin/bash

# Parameters that customizes the system-install

  # BCACHEFS-support
  if ! grep -q bcachefs "/proc/filesystems"; then BCACHEFS_implemented="false"; BCACHEFS_notice="BCACHEFS as filesystem # NOTICE: Currently not implemented"
  else BCACHEFS_implemented="true"; BCACHEFS_notice="BCACHEFS as filesystem"; fi

  # Subvolumes to be created 
  subvolumes=(\@ "home" "var/cache" "var/log" "var/tmp" "opt" "srv" "root" "grub")

  # Groups which user is added to 
  export USER_groups="wheel,realtime,video,audio,network,uucp,input,storage,disk,lp,scanner,games"

  # Miscellaneous security enhancements 
  export LOGIN_delay="3000000" # Delays initial login with 3 seconds if wrong credentials

#----------------------------------------------------------------------------------------------------------------------------------

# Choices to present in text-menu

  intro=(
    "INTRO"
    "FILESYSTEM_primary_btrfs:BTRFS as filesystem"
    "FILESYSTEM_primary_bcachefs:$BCACHEFS_notice"
    "HOME_partition:Make a separate /home-partition"
	"SWAP_partition:Create a swap-partition"
    "ENCRYPTION_partitions:Encryption" 
    "INIT_choice_runit:runit as init" 
    "INIT_choice_openrc:openrc as init" 
    "INIT_choice_dinit:dinit as init" 
    "BOOTLOADER_choice_grub:GRUB as bootloader" 
    "BOOTLOADER_choice_refind:REFIND as bootloader # NOTICE: not implemented yet" 
    "REPLACE_networkmanager:Replace NetworkManager with connman # NOTICE: connman doesn't conflict with NetworkManager"
    "REPLACE_sudo:Replace sudo with doas # NOTICE: doas doesn't conflict with sudo" 
    "REPLACE_elogind:Replace elogind with seatd # NOTICE: a elogind-dummy-package is installed, though NetworkManager requires elogind"
    "POST_script:Execute post-install script as regular user"
)

  drive_selection=(
    "DRIVE_SELECTION"
    "${DRIVES[@]}"
)

  PARTITIONS_full="VALUE,BOOT-PARTITION (1),HOME-PARTITION (2),ROOT-PARTITION (3),SWAP-SIZE (4)"
  PARTITIONS_without_home="VALUE,BOOT-PARTITION (1),ROOT-PARTITION (2),SWAP-SIZE (3)"
  LOCALS="VALUE,TIMEZONE (1),LANGUAGES (2),KEYMAP (3),HOSTNAME (4)"
  USERS="VALUE,root (1),personal (2)"
  MISCELLANEOUS=",BOOTLOADER-ID (1),ADDITIONAL PACKAGES (2),POST INSTALL SCRIPT (3)"

#----------------------------------------------------------------------------------------------------------------------------------

# Function to update user-chosen choices when printing

  UPDATE_CHOICES() {
    read -r -d '' OUTPUT_partitions_full << EOM
$PARTITIONS_full
SIZE:,$BOOT_size MB,$HOME_size GB,$PRIMARY_size GB,$SWAP_size GB
LABEL:,$BOOT_label,$HOME_label,$PRIMARY_label,$SWAP_label
ENCRYPTION-password:,,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_partitions_without_home << EOM
$PARTITIONS_without_home
SIZE:,$BOOT_size MB,$PRIMARY_size GB,$SWAP_size MB
LABEL:,$BOOT_label,$PRIMARY_label,$SWAP_label
ENCRYPTION-password:,,$ENCRYPTION_passwd
EOM

    read -r -d '' OUTPUT_locals << EOM
$LOCALS
GENERATED:,,$LANGUAGES_generate
SYSTEMWIDE:,$TIMEZONE,$LANGUAGE_system,$KEYMAP_system,$HOSTNAME_system
EOM

    read -r -d '' OUTPUT_users << EOM
$USERS
USERNAME:,$ROOT_username,$USERNAME
PASSWORD:,$ROOT_passwd,$USER_passwd
EOM

    read -r -d '' OUTPUT_miscellaneous << EOM
$MISCELLANEOUS
VALUE:,$BOOTLOADER_label,$PACKAGES_additional,$POST_install_script
PATH:,,,$POST_install_script_name
EOM
}
