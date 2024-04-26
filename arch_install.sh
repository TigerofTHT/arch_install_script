#!/bin/bash

set -e

disk="/dev/sda"

chrootenv() {
        echo -e "\n\e[1;37mPreparing chroot enviroment...\e[0m\n"
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
        #syslinux-install_update -i -a -m
        if [ ! -d /sys/firmware/efi ]
        then
                grub-install --target=i386-pc $disk
                grub-mkconfig -o /boot/grub/grub.cfg
        else        
                grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
                grub-mkconfig -o /boot/grub/grub.cfg
        fi
}                      

timedatectl status

while getopts "mu" opt
do
        case $opt in 
                m)      echo -e "\n\e[1;37mPreparing disk with MBR...\e[0m\n"
                        parted -s -a optimal $disk mklabel msdos \
                                        mkpart primary linux-swap 0% 4G \
                                        mkpart primary ext4 4G 100% print
                        mkswap $disk"1"
                        mkfs.ext4 $disk"2"
                        swapon $disk"1"
                        mount $disk"2" /mnt
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export disk
                        export -f chrootenv
                        arch-chroot /mnt /bin/bash -c chrootenv
                        ;;
                
                u)      echo -e "\n\e[1;37mPreparing disk with UEFI...\e[0m\n"
                        parted -s -a optimal $disk mklabel gpt \
                                        mkpart primary fat32 0% 1G \
                                        mkpart primary linux-swap 1G 4G \
                                        mkpart primary ext4 4G 100% print
                        mkfs.fat -F 32 $disk"1"
                        mkswap $disk"2"
                        mkfs.ext4 $disk"3"
                        swapon $disk"2"
                        mount $disk"3" /mnt
                        mount -m $disk"1" /mnt/boot
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux \
                                        efibootmgr 
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export disk
                        export -f chrootenv
                        arch-chroot /mnt /bin/bash -c chrootenv
                        ;;
        esac 
done

umount -R /mnt