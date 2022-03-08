# Artix installation script

A customizable install-script for Artix Linux that can either be executed interactively with prompts or automatic - an automatic install requires modifying the provided answerfile.

By default, the following is set up:

- BTRFS-subvolumes with support for snapshots; taken pre and post system-update
- Paru as AUR-helper
- GRUB as bootloader
- Arch-repositories enabled

while the following are decided by the user:

- LUKS2-encryption of /
    - Due to GRUB-limitations, a prompt for the passphrase will emerge twice
 
- Swap-partition
- Choice of init; dinit, openrc or runit
- Replace 'default' packages - e.g. sudo - with an alternative - e.g. doas
- Install additional packages


## Installation

If using the official ISO by Artix Linux:

```bash
loadkeys KEYMAP
connmanctl 
enable wifi
scan wifi
agent on
services
connect WIFI_ID
pacman -Sy --noconfirm git
git clone https://gitlab.com/FabseGP02/artix-install-script.git
cd artix-install-script
./install_artix.sh # Remember to replace the answerfile, if an automatic install is desired
````

## TODO
In no given order:

- [ ] Support for bcachefs once mainlined into linux-kernel
- [ ] Integration with post-script to fully setup your system


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[GPL](https://choosealicense.com/licenses/gpl-3.0/)
