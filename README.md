# Artix installation script

A customizable install-script for Artix Linux that can either be executed interactively with prompts or automatic - an automatic install requires modifying the provided answerfile.

By default, the following is set up:

- Subvolumes with support for snapshots
- Paru as AUR-helper; of course aliased to yay!
- Arch-repositories enabled
- The following pacman-hooks:
    - Cleaning package cache to only keep the two latest versions
    - Creating snapshots pre and post kernel update/install + recreates grub.cfg
- The following packages:
    - GRUB as bootloader
    - linux-zen, linux-zen-headers and linux-firmware
    - cronie (used for snapshots-cleaning), cryptsetup (for encrypted swap alone, if no encryption of /), iwd (replaces wpa_supplicant), chrony (used to keep check of system-time) and backlight (saves previous brightness) as init-services
    - Either intel-ucode or amd-ucode depending on your CPU
    - booster as a fast replacement for mkinitcpioe
    - Filesystem utilies; either btrfs-progs or bcachefs-tools + dosfstools (for FAT32)
    - Miscellaneous packages: iptables-nft (replaces iptables), pacman-contrib (provides paccache and more), snap-pac and base-devel

while the following are decided by the user:

- Choice of filesystem; either btrfs or bcachefs
    - NOTICE: Bcachefs is yet to be mainlined into the kernel
- LUKS2-encryption of /
    - Currently booster doesn't support encryption-keys, whereas two password-prompts (one for unlocking /boot and /) will emerge on boot; set to be added in 0.9 release
- Swap-partition
- Choice of init; dinit, openrc or runit
- Replacing the following packages with alternatives:
    - Replace elogind with seatd; will install an elogind-dummy-package
    - Replace networkmanager with connman
    - Replace sudo with doas
- Install additional packages
- Execute custom script after install as regular user
- Locals and users


## Installation

If using the official ISO by Artix Linux:

```bash
loadkeys KEYMAP
connmanctl 
  enable wifi
  scan wifi
  agent on
  services
  connect WIFI_ID # connmanctl has tab-completion
  exit
pacman -Sy --noconfirm git
git clone https://gitlab.com/FabseGP02/artix-install-script.git
cd artix-install-script
chmod u+x install_artix.sh
./install_artix.sh # Remember to replace the answerfile, if an automatic install is desired
````

## TODO
In no given order:

- [ ] Support for bcachefs once mainlined into linux-kernel
- [X] Integration with post-script to fully setup your system
- [ ] Option to return to the previous submenu; currently only to start of script


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GPL](https://choosealicense.com/licenses/gpl-3.0/)
