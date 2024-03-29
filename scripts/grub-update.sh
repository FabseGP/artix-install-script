#!/usr/bin/bash

  source /.secret/bootloader-id
  cp /.secret/10_linux /etc/grub.d/10_linux
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="$BOOTLOADER_label"
  if [[ -f "/.secret/grub-pre.cfg" ]]; then
    grub-mkimage -p '/boot/grub' -O x86_64-efi -c /.secret/grub-pre.cfg -o /tmp/image luks2 btrfs part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha512
    cp /tmp/image /boot/efi/EFI/"$BOOTLOADER_label"/grubx64.efi
  fi
  
