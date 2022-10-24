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
        systemctl enable dhcpcd
        passwd
        syslinux-install_update -i -a -m
}

timedatectl status

while getopts "m:u" opt
do
        case $opt in 
                m)
                        echo -e "\nPreparing disk with MBR...\n"
                        parted -s -a optimal $disk mklabel msdos \
                                        mkpart primary linux-swap 0% 4G \
                                        mkpart primary ext4 4G 100% print
                        mkswap $disk"1"
                        mkfs.ext4 $disk"2"
                        swapon $disk"1"
                        mount $disk"2" /mnt
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux 
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export -f chrootenv
                        arch-chroot /mnt /bin/bash -c chrootenv
                        ;;
                
                u)      echo -e "\nPreparing disk with UEFI...\n"
                        parted -s -a optimal $disk mklabel msdos \
                                        mkpart primary fat32 0% 256M \
                                        mkpart primary linux-swap 256M 4G \
                                        mkpart primary ext4 4G 100% print
                        mkfs.fat -F 32 $disk"1"
                        mkswap $disk"2"
                        mkfs.ext4 $disk"3"
                        swapon $disk"2"
                        mount $disk"3" /mnt
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux 
                        mount $disk"1" /mnt/boot
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export -f chrootenv
                        arch-chroot /mnt /bin/bash -c chrootenv
                        ;;
        esac 
done

umount -R /mnt