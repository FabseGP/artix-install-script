#!/usr/bin/bash

# Functions that installs artix

  SCRIPT_01_REQUIRED_PACKAGES() {
    if [[ -z "$(pacman -Qs lolcat)" ]]; then
      printf "%s" "Installing dependencies "
      local command="pacman -Sy --noconfirm --needed lolcat figlet parted wget"
      $command > /dev/null 2>&1 &
      while ! [[ $(pacman -Qs lolcat) ]]; do
        PRINT_PROGRESS_BAR 
        sleep 1
      done
      printf " [%s]\n" "Success!"
    fi
    if [[ -z "$(pacman -Qs artix-archlinux-support)" ]]; then
      if [[ "$INTERACTIVE_INSTALL" == "true" ]]; then
        scripts/repositories.sh > /dev/null 2>&1 &
      else
        scripts/repositories.sh
      fi
    fi
}
 
  SCRIPT_02_CHOICES() {
    eval "${messages[0]}"
    export ENTRY="intro"
    MULTISELECT_MENU "${intro[@]}"
    if [[ "$INIT_choice_runit" == "true" ]]; then
      export INIT_choice="runit"
    elif [[ "$INIT_choice_openrc" == "true" ]]; then
      export INIT_choice="openrc"
    elif [[ "$INIT_choice_dinit" == "true" ]]; then
      export INIT_choice="dinit"
    fi
    if [[ "$BOOTLOADER_choice_grub" == "true" ]]; then
      export BOOTLOADER_choice="grub"
    elif [[ "$BOOTLOADER_choice_refind" == "true" ]]; then
      export BOOTLOADER_choice="openrc"
    fi
}

  SCRIPT_03_CUSTOMIZING() {
    if [[ "$ENCRYPTION_partitions" == "false" ]]; then
      export ENCRYPTION_passwd="IGNORED"
    fi
    if [[ "$POST_script" == "false" ]]; then
      export POST_install_script="IGNORED"
      export POST_install_script_name="IGNORED"
    fi
    UPDATE_CHOICES
    MULTISELECT_MENU "${drive_selection[@]}"
    PRINT_MESSAGE "${messages[9]}" 
    if [[ "$ZRAM" == "true" ]]; then
      if [[ "$HOME_partition" == "true" ]]; then
        PRINT_TABLE ',' "$OUTPUT_partitions_full"
        CUSTOMIZING_INSTALL PARTITIONS_full
      else
        PRINT_TABLE ',' "$OUTPUT_partitions_without_home"
        CUSTOMIZING_INSTALL PARTITIONS_without_home
      fi
    else
      if [[ "$HOME_partition" == "true" ]]; then
        PRINT_TABLE ',' "$OUTPUT_partitions_without_swap"
        CUSTOMIZING_INSTALL PARTITIONS_without_swap
      else
        PRINT_TABLE ',' "$OUTPUT_partitions_minimal"
        CUSTOMIZING_INSTALL PARTITIONS_minimal
      fi
    fi
    PRINT_MESSAGE "${messages[10]}" 
    PRINT_TABLE ',' "$OUTPUT_locals"
    CUSTOMIZING_INSTALL LOCALS
    PRINT_MESSAGE "${messages[11]}" 
    PRINT_TABLE ',' "$OUTPUT_users"
    CUSTOMIZING_INSTALL USERS
    PRINT_MESSAGE "${messages[12]}" 
    PRINT_TABLE ',' "$OUTPUT_miscellaneous"
    CUSTOMIZING_INSTALL MISCELLANEOUS
}

  SCRIPT_04_UMOUNT_MNT() {
    if [[ "$(mountpoint /mnt)" ]]; then
      swapoff -a
      umount -A --recursive /mnt
    fi
}

  SCRIPT_05_CREATE_PARTITIONS() {
    if [[ "$HOME_partition" == "true" ]]; then
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart HOME "$BOOT_size"MiB "$HOME_size"GiB \
        mkpart PRIMARY "$HOME_size"GiB 100% 
    else
      parted --script -a optimal "$DRIVE_path" \
        mklabel gpt \
        mkpart BOOT fat32 1MiB "$BOOT_size"MiB set 1 ESP on \
        mkpart PRIMARY "$BOOT_size"MiB 100% 
    fi
}

  SCRIPT_06_FORMAT_AND_ENCRYPT_PARTITIONS() {
    mkfs.vfat -F32 -n "$BOOT_label" "$DRIVE_path_boot" 
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        if [[ "$HOME_partition" == "true" ]]; then
          echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_home"
          echo "$ENCRYPTION_passwd" | cryptsetup open --allow-discards --perf-no_read_workqueue --size 4196 --persistent "$DRIVE_path_home" crypthome
          mkfs.btrfs -f -L "$HOME_label" /dev/mapper/crypthome
          mkfs.btrfs -f -L "$PRIMARY_label" "$DRIVE_path_primary"
          MOUNTPOINT="$DRIVE_path_primary"
        else
          echo "$ENCRYPTION_passwd" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 --cipher aes-xts-plain64 --key-size 512 --hash sha512 --use-random "$DRIVE_path_primary" # GRUB currently lacks support for ARGON2d
          echo "$ENCRYPTION_passwd" | cryptsetup open --allow-discards --perf-no_read_workqueue --size 4196 --persistent "$DRIVE_path_primary" cryptroot
          mkfs.btrfs -f -L "$PRIMARY_label" /dev/mapper/cryptroot
          MOUNTPOINT="/dev/mapper/cryptroot"
        fi
      else
        mkfs.btrfs -f -L "$PRIMARY_label" "$DRIVE_path_primary"
        MOUNTPOINT="$DRIVE_path_primary"
        if [[ "$HOME_partition" == "true" ]]; then
          mkfs.btrfs -f -L "$HOME_label" "$DRIVE_path_home"
        fi
      fi
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      if [[ "$ENCRYPTION_partitions" == "true" ]]; then
        if [[ "$HOME_partition" == "true" ]]; then
          bcachefs format -f --encrypted --compression_type=zstd -L "$HOME_label" "$DRIVE_path_home"
          bcachefs unlock "$DRIVE_path_home"
        else
          bcachefs format -f --encrypted --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary"
          bcachefs unlock "$DRIVE_path_primary"
        fi
        MOUNTPOINT="$DRIVE_path_primary"
      else
        bcachefs format -f --compression_type=zstd -L "$PRIMARY_label" "$DRIVE_path_primary" 
        if [[ "$HOME_partition" == "true" ]]; then
          bcachefs format -f --compression_type=zstd -L "$HOME_label" "$DRIVE_path_home" 
        fi       
      fi
    fi
}

  SCRIPT_07_CREATE_SUBVOLUMES_AND_MOUNT_PARTITIONS() {
    export UUID_1=$(blkid -s UUID -o value "$DRIVE_path_primary")
    export UUID_home=$(blkid -s UUID -o value "$DRIVE_path_home")
    export UUID_2=$(lsblk -no TYPE,UUID "$DRIVE_path_primary" | awk '$1=="part"{print $2}' | tr -d -)
    mount -o noatime,compress=zstd "$MOUNTPOINT" /mnt
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        if ! [[ "${subvolumes[subvolume]}" == "@" ]]; then
          if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
            chattr +C "${subvolumes[subvolume]}"
          elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
            btrfs subvolume create "/mnt/@/boot/grub"
          elif [[ "${subvolumes[subvolume]}" == "home" ]]; then 
            btrfs subvolume create "/mnt/@/home"
          else
            btrfs subvolume create "/mnt/@/${subvolumes[subvolume]}"
          fi
        else
          btrfs subvolume create "/mnt/${subvolumes[subvolume]}"
          mkdir -p /mnt/@/{var,boot}
        fi
      elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
        bcachefs subvolume create "${subvolumes[subvolume]}"
      fi
    done
    umount /mnt
    mount "$MOUNTPOINT" -o noatime,compress=zstd /mnt
    mkdir -p /mnt/{etc/pacman.d/hooks,.secret,home,btrbk_snapshots}
    for ((subvolume=0; subvolume<${#subvolumes[@]}; subvolume++)); do
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        subvolume_path=$(string="${subvolumes[subvolume]}"; echo "${string//@/}")
        if ! [[ "${subvolumes[subvolume]}" == "@" ]]; then
          if ! [[ "${subvolumes[subvolume]}" == "grub" ]]; then
            mkdir -p /mnt/"${subvolumes[subvolume]}"
            if [[ "${subvolumes[subvolume]}" == "var/*" ]]; then
              mount -o noatime,nodatacow,discard=async,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
            if [[ "${subvolumes[subvolume]}" == "home" ]]; then
              if ! [[ "$HOME_partition" == "true" ]]; then
                mount -o noatime,compress=zstd,discard=async,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
              fi
            fi
            else
              mount -o noatime,compress=zstd,discard=async,subvol="@/${subvolumes[subvolume]}" "$MOUNTPOINT" /mnt/"$subvolume_path"
            fi  
          elif [[ "${subvolumes[subvolume]}" == "grub" ]]; then
            mkdir -p /mnt/boot/{efi,grub}
            mount -o noatime,compress=zstd,discard=async,nodev,noexec,nosuid,subvol="@/boot/grub" "$MOUNTPOINT" /mnt/boot/grub
          fi
        fi
      elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
        :
      fi
    done
    sync
    cd "$BEGINNER_DIR" || exit
    mount -o nodev,nosuid,noexec "$DRIVE_path_boot" /mnt/boot/efi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      if [[ "$HOME_partition" == "true" ]]; then
        if [[ "$ENCRYPTION_partitions" == "true" ]]; then
          mount -o noatime,compress=zstd,discard=async /dev/mapper/crypthome /mnt/home
        else
          mount -o noatime,compress=zstd,discard=async "$DRIVE_path_home" /mnt/home
        fi
        mkdir /mnt/home/btrbk_snapshots
      fi
    elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
      :
    fi
}	
 
  SCRIPT_08_BASESTRAP_PACKAGES() {         
    if grep -q Intel "/proc/cpuinfo"; then # Poor soul :(
      ucode="intel-ucode"
    elif grep -q AMD "/proc/cpuinfo"; then
      ucode="amd-ucode"
    fi
    if [[ "$REPLACE_sudo" == "true" ]]; then
      su="opendoas"
    else
      su="sudo"
    fi
    if [[ "$ZRAM" == "true" ]]; then
      zramen="zramen-$INIT_choice"
    fi
    if [[ "$BOOTLOADER_choice" == "refind" ]]; then
      bootloader="refind"
    elif [[ "$BOOTLOADER_choice" == "grub" ]]; then
      bootloader="grub"
    fi
    if [[ "$REPLACE_elogind" == "true" ]]; then
      seat="seatd-$INIT_choice"
    else
      seat="elogind-$INIT_choice"
    fi
    if [[ "$REPLACE_networkmanager" == "true" ]]; then
      network="connman-$INIT_choice"
    else
      network="networkmanager-$INIT_choice"
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      filesystem="grub-btrfs"
    else
      filesystem="bcachefs-tools"
    fi
    basestrap /mnt $INIT_choice cronie-$INIT_choice cryptsetup-$INIT_choice iwd-$INIT_choice backlight-$INIT_choice \
                   chrony-$INIT_choice booster zstd realtime-privileges efibootmgr base base-devel dosfstools git \
                   iptables-nft pacman-contrib linux-zen linux-zen-headers linux-firmware $ucode $seat $network \
                   $su $filesystem $zramen $bootloader --ignore mkinitcpio
}

  SCRIPT_09_FSTAB_GENERATION() {
    fstabgen -U /mnt >> /mnt/etc/fstab
    if [[ "$HOME_partition" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      cat << EOF | tee -a /mnt/etc/crypttab > /dev/null
home UUID=$UUID_home none luks,timeout=300
EOF
    fi
}

  SCRIPT_10_CHROOT() {
    mkdir /mnt/install_script
    cd "$BEGINNER_DIR" || exit
    cp -r -- * /mnt/install_script
    for ((function=0; function < "${#functions[@]}"; function++)); do
      if [[ "${functions[function]}" == *"SYSTEM"* ]]; then
        export -f "${functions[function]}"
        artix-chroot /mnt /bin/bash -c "${functions[function]}"
      fi
    done
}

#----------------------------------------------------------------------------------------------------------------------------------

# Functions that configures artix

  SYSTEM_01_LOCALS() {
    # Timezone
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    hwclock --systohc
    # Language(s)
    j=1
    IFS=' ' 
    read -ra LANGUAGES_array <<< "$LANGUAGES_generate"
    for language in "${LANGUAGES_array[@]}"; do
      sed -i '/'"$language"'/s/^#//g' /etc/locale.gen
    done
    locale-gen
    echo "LANG="$LANGUAGE_system"" >> /etc/locale.conf
    echo "LC_ALL="$LANGUAGE_system"" >> /etc/locale.conf
    # Keymap
    echo "KEYMAP="$KEYMAP_system"" >> /etc/vconsole.conf
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "KEYMAP="$KEYMAP_system"" >> /etc/conf.d/keymaps
    fi
    # Hostname
    echo "$HOSTNAME_system" >> /etc/hostname
    if [[ "$INIT_choice" == "openrc" ]]; then
      echo "hostname='"$HOSTNAME_system"'" >> /etc/conf.d/hostname
    fi
    cat << EOF | tee -a /etc/hosts > /dev/null
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME_system.localdomain $HOSTNAME_system 
EOF
}

  SYSTEM_02_USERS() {
    echo "root:$ROOT_passwd" | chpasswd
    useradd -m  -G "$USER_groups" "$USERNAME"
    if [[ "$REPLACE_elogind" == "true" ]]; then
      groupadd seatd
      usermod -a -G seatd "$USERNAME"
    fi
    echo -e "$USER_passwd\n$USER_passwd\n" | passwd $USERNAME
}

  SYSTEM_03_ADDITIONAL_PACKAGES() {
    cd /install_script/scripts || exit
    ./repositories.sh
    if ! [[ "$PACKAGES_additional" == "NONE" ]]; then
      pacman -S --noconfirm --needed "$PACKAGES_additional"
    fi
}

  SYSTEM_04_AUR() {
    cd /install_script/packages || exit
    PARU="$(ls -- *paru-*)"
    pacman -U --noconfirm $PARU
    cd /install_script || exit
    cp configs/bash.bashrc /etc/bash.bashrc
    mkdir -p /home/"$USERNAME"
    chown -R "$USERNAME": /home/"$USERNAME"
    cp configs/bash.bashrc /home/"$USERNAME"/.bashrc
    cp /install_script/configs/paru.conf /etc/paru.conf # Links sudo to doas + more
    cp /install_script/configs/makepkg.conf /etc/makepkg.conf
    if [[ "$core_count" -gt 1 ]]; then 
      sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$core_count\"/g" /etc/makepkg.conf
    fi
}

  SYSTEM_05_SUPERUSER() {
    if [[ "$REPLACE_sudo" == "true" ]]; then
      touch /etc/doas.conf
      cat << EOF | tee -a /etc/doas.conf > /dev/null
permit persist setenv { XAUTHORITY LANG LC_ALL } :wheel
EOF
      chown -c root:root /etc/doas.conf
      chmod -c 0400 /etc/doas.conf
      for path in "/etc/bash.bashrc" "/home/"$USERNAME"/.bashrc"; do
        cat << EOF | tee -a $path > /dev/null 
# Redirect sudo to doas
alias sudo=doas   

# Adds tab-completion
complete -cf doas

EOF
      done
    else
      sed -i -e "/Sudo = doas/s/^#*/#/" /etc/paru.conf
      echo "%wheel ALL=(ALL) ALL" | (EDITOR="tee -a" visudo)
    fi
}

  SYSTEM_06_SERVICES() {
    if [[ "$REPLACE_networkmanager" == "true" ]]; then
      export network_manager="connmand"
    else
      pacman -S --noconfirm polkit
      export network_manager="NetworkManager"
      touch /etc/NetworkManager/conf.d/wifi_backend.conf
      cat << EOF | tee -a /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null
[device]
wifi.backend=iwd
EOF
    fi
    for service in $network_manager cronie backlight chronyd zramen; do
      if [[ "$service" == "zramen" ]]; then
        if [[ "$ZRAM" == "true" ]]; then
          if [[ "$INIT_choice" == "dinit" ]]; then
            ln -s /etc/dinit.d/$service /etc/dinit.d/boot.d
          elif [[ "$INIT_choice" == "runit" ]]; then
            ln -s /etc/runit/sv/$service /etc/runit/runsvdir/default
          elif [[ "$INIT_choice" == "openrc" ]]; then
            rc-update add $service
          fi
        fi
      else
        if [[ "$INIT_choice" == "dinit" ]]; then
          ln -s /etc/dinit.d/$service /etc/dinit.d/boot.d
        elif [[ "$INIT_choice" == "runit" ]]; then
          ln -s /etc/runit/sv/$service /etc/runit/runsvdir/default
        elif [[ "$INIT_choice" == "openrc" ]]; then
          rc-update add $service
        fi
      fi
    done
}

  SYSTEM_07_CRYPTKEY() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]] && [[ "$ENCRYPTION_partitions" == "true" ]]; then
      dd bs=512 count=6 if=/dev/random of=/.secret/crypto_keyfile.bin iflag=fullblock
      chmod 600 /.secret/crypto_keyfile.bin
      chmod 600 /boot/booster-linux*
      echo "$ENCRYPTION_passwd" | cryptsetup luksAddKey "$DRIVE_path_primary" /.secret/crypto_keyfile.bin
    fi
}

  SYSTEM_08_SNAPSHOTS() {
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      cd /install_script/packages || exit
      BTRBK="$(ls -- *btrbk-*)"
      pacman -U --noconfirm $BTRBK
      cd /install_script || exit
      cp configs/btrbk.conf /etc/btrbk/btrbk.conf
      cp services/cron/daily/btrbk /etc/cron.daily
      cp services/cron/hourly/btrbk /etc/cron.hourly
    fi
}

  SYSTEM_09_BOOTLOADER() {
    cd /install_script || exit
    if [[ "$BOOTLOADER_choice" == "grub" ]]; then
      cp configs/10_linux /etc/grub.d/10_linux
      cp configs/10_linux /.secret
      touch /.secret/bootloader-id
      cat << EOF | tee -a /.secret/bootloader-id > /dev/null
#!/bin/sh

  BOOTLOADER_label=$BOOTLOADER_label
EOF
      if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
        sed -i 's/rootflags=subvol=${rootsubvol}//' /etc/grub.d/20_linux_xen  
        if [[ "$ENCRYPTION_partitions" == "true" ]] && ! [[ "$HOME_partition" == "true" ]]; then	
          sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ splash\ nowatchdog\ rd.luks.name='"$UUID_1"'=cryptroot\ root=\/dev\/mapper\/cryptroot\ rd.luks.allow-discards\ rd.luks.key=\/.secret\/crypto-keyfile.bin"/' /etc/default/grub
          sed -i 's/GRUB_PRELOAD_MODULES="part_gpt part_msdos"/GRUB_PRELOAD_MODULES="part_gpt\ part_msdos\ luks2"/' /etc/default/grub
          sed -i -e "/GRUB_ENABLE_CRYPTODISK/s/^#//" /etc/default/grub
          grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
          touch grub-pre.cfg
          cat << EOF | tee -a grub-pre.cfg > /dev/null
cryptomount -u $UUID_2 
set root=crypto0
set prefix=(crypto0)/@/boot/grub
insmod normal
normal
EOF
          grub-mkimage -p '/boot/grub' -O x86_64-efi -c grub-pre.cfg -o /tmp/image luks2 btrfs part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha512
          cp /tmp/image /boot/efi/EFI/"$BOOTLOADER_label"/grubx64.efi
          grub-mkconfig -o /boot/grub/grub.cfg
          cp grub-pre.cfg /.secret
          rm -rf {/tmp/image,grub-pre.cfg}
        fi
      elif [[ "$FILESYSTEM_primary_bcachefs" == "true" ]]; then
        :
      fi
      if ! [[ "$ENCRYPTION_partitions" == "true" ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ splash\ nowatchdog"/' /etc/default/grub
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
        grub-mkconfig -o /boot/grub/grub.cfg
      fi
      if [[ "$ENCRYPTION_partitions" == "true" ]] && [[ "$HOME_partition" == "true" ]]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3\ quiet\ splash\ nowatchdog"/' /etc/default/grub
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
        grub-mkconfig -o /boot/grub/grub.cfg
      fi
    elif [[ "$BOOTLOADER_choice" == "refind" ]]; then
      :
    fi
}

  SYSTEM_10_PACKAGES_INSTALL_AND_REMOVE() {
    cd /install_script/packages || exit  
    if [[ "$REPLACE_sudo" == "true" ]]; then
      pacman -Rns --noconfirm sudo
    fi
    if [[ "$REPLACE_elogind" == "true" ]]; then
      ELOGIND="$(ls -- *elogind-*)"
      pacman -U --noconfirm $ELOGIND
      pacman -S --noconfirm pam_rundir
    fi
    ANANICY="$(ls -- *ananicy-*)"
    pacman -U --noconfirm $ANANICY
}

  SYSTEM_11_MISCELLANEOUS() {
    cd /install_script || exit
    cat << EOF | tee -a /etc/pam.d/system-login > /dev/null
auth optional pam_faildelay.so delay="$LOGIN_delay"
EOF
    sed -i 's/nullok//g' /etc/pam.d/system-auth
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/g' /etc/pam.d/su
    sed -i 's/#auth           required        pam_wheel.so use_uid/auth           required        pam_wheel.so use_uid/g' /etc/pam.d/su-l
    echo 'PRUNENAMES = "btrbk_snapshots"' >> /etc/updatedb.conf # Prevent snapshots from being indexed
    if [[ "$INIT_choice" == "openrc" ]]; then
      sed -i 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf
      sed -i 's/#unicode="NO"/unicode="YES"/g' /etc/rc.conf
      sed -i 's/#rc_depend_strict="YES"/rc_depend_strict="NO"/g' /etc/rc.conf
      cp services/openrc/ananicy/ananicy-cpp-openrc /etc/init.d/ananicy-cpp
      ln -s /etc/dinit.d/ananicy-cpp /etc/dinit.d/boot.d
      rc-update add ananicy-cpp
      if [[ "$ZRAM" == "true" ]]; then
        sed -i 's/CHANGEME/'"$SWAP_size_percentage"'/g' services/openrc/zramen/zramen-openrc
        cp services/openrc/zramen/zramen-openrc /etc/init.d/zramen
      fi
    elif [[ "$INIT_choice" == "runit" ]]; then
      mkdir /etc/runit/sv/ananicy-cpp
      cp services/runit/ananicy/* /etc/runit/sv/ananicy-cpp
      ln -s /etc/runit/sv/ananicy-cpp /etc/runit/runsvdir/default
      if [[ "$ZRAM" == "true" ]]; then
        sed -i 's/CHANGEME/'"$SWAP_size_percentage"'/g' services/runit/zramen/zramen-runit
        cp services/runit/zramen/zramen-runit /etc/runit/sv/zramen/run
      fi
    elif [[ "$INIT_choice" == "dinit" ]]; then
      cp services/dinit/ananicy/ananicy-cpp-dinit /etc/dinit/ananicy-cpp
      ln -s /etc/dinit.d/ananicy-cpp /etc/dinit.d/boot.d
      if [[ "$ZRAM" == "true" ]]; then
        sed -i 's/CHANGEME/'"$SWAP_size_percentage"'/g' services/dinit/zramen/zramen-dinit
        cp services/dinit/zramen/zramen-dinit /etc/dinit.d/scripts/zramen
        cp services/dinit/zramen/zramen-diinit-start /etc/dinit.d/zramen
      fi
    fi
    if [[ "$FILESYSTEM_primary_btrfs" == "true" ]]; then
      cp services/cron/weekly/btrfs_health /etc/cron.weekly
    fi
    cp scripts/{ranking-mirrors,grub-update} /usr/share/libalpm/scripts
    cp hooks/* /etc/pacman.d/hooks
    pacman -S --noconfirm artix-mirrorlist artix-archlinux-support
    cd /install_script/packages || exit
    PACDIFF="$(ls -- *pacdiff-*)"
    pacman -U --noconfirm $PACDIFF
    cd $BEGINNER_DIR || exit
    if [[ "$REPLACE_networkmanager" == "true" ]] && [[ "$REPLACE_elogind" == "true" ]]; then
      cp configs/50-org.freedesktop.NetworkManager.rules /etc/polkit-1/rules.d/
    fi
}

  SYSTEM_12_POST_SCRIPT() {
    if [[ "$POST_script" == "true" ]] && ! [[ "$POST_install_script" == "NONE" ]]; then
      export basename=$(basename $POST_install_script)
      export basename_clean=${basename%.*}
      if [[ "$REPLACE_sudo" == "true" ]]; then
        echo "permit nopass $USERNAME" | tee -a /etc/doas.conf > /dev/null
      else
        echo ""$USERNAME" ALL=(ALL:ALL) NOPASSWD: ALL" | tee -a /etc/sudoers > /dev/null
      fi
      su -l "$USERNAME" -c "git clone https://$POST_install_script; cd "$basename_clean"; chmod u+x "$POST_install_script_name"; bash "$POST_install_script_name""
      rm -rf /home/$USERNAME/$basename_clean
      if [[ "$REPLACE_sudo" == "true" ]]; then
        sed -i "/permit nopass $USERNAME/d" /etc/doas.conf
      else
        sed -i "/$USERNAME ALL=(ALL) NOPASSWD: ALL/d" /etc/sudoers
      fi
    fi
}

  SYSTEM_13_CLEANUP() {
    rm -rf /install_script
}

  SCRIPT_11_FAREWELL() {
    echo
    PRINT_MESSAGE "${messages[13]}" 
    exec env --ignore-environment /bin/bash
    exit
}

  # Must be the last command in this section to export all defined functions
  mapfile -t functions < <( compgen -A function ) 
