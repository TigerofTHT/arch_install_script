#!/bin/bash

set -e

disk="/dev/sda"

chrootenv() {
        echo -e "\nPreparing chroot enviroment...\n"
        echo "Setup time zone..."
        ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
        hwclock --systohc
        echo "Setup localization..."
        sed -i '/en_US\./s/^#//' /etc/locale.gen
        sed -i '/de_DE\./s/^#//' /etc/locale.gen
        locale-gen
        echo "KEYMAP=de-latin1" >> /etc/vconsole.conf
        echo "tiger-arch" >> /etc/hostname
        echo "Generating initramfs..."
        mkinitcpio -P
        passwd
        syslinux-install_update -i -a -m
}

timedatectl status

while getopts "m" opt
do
        case $opt in 
            m)
                    echo -e "\nPreparing disk with MBR...\n"
                    parted -s -a optimal $disk mklabel msdos \ 
                            mkpart primary linux-swap 0% 128M \ 
                            mkpart primary ext4 4G 100% print
                    mkswap $disk"1"
                    mkfs.ext4 $disk"2"
                    swapon $disk"1"
                    mount $disk"2" /mount
                    pacstrap -K /mnt base linux linux-firmware nano syslinux
                    genfstab -U /mnt >> /mnt/etc/fstab
                    arch-chroot /mnt /bin/bash -c chrootenv
                    ;;
        esac 
done

umount -R /mnt