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
        #syslinux-install_update -i -a -m
        boot=$(blkid | grep $disk"1" | cut -b 52-55) 
        if [ "$boot" != "vfat" ]
                then
                        mbr
                else
                        uefi
        fi
}                      

mbr() {
        syslinux-install_update -i -a -m        
}

uefi(){
        mkdir -p esp/EFI/syslinux
        cp -r /usr/lib/syslinux/efi64/* esp/EFI/syslinux
        efibootmgr --create --disk $disk --part Y --loader /EFI/syslinux/syslinux.efi --label "Syslinux" --unicode
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
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux                                       efibootmgr
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export -f chrootenv mbr
                        arch-chroot /mnt /bin/bash -c chrootenv mbr
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
                        mount -m $disk"1" /mnt/boot
                        pacstrap -K /mnt base linux linux-firmware nano dhcpcd syslinux \ 
                                        efibootmgr 
                        genfstab -U /mnt >> /mnt/etc/fstab
                        export -f chrootenv uefi
                        arch-chroot /mnt /bin/bash -c chrootenv uefi
                        ;;
        esac 
done

umount -R /mnt