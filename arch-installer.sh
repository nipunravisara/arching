# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 2`
reset=`tput sgr0`

echo "${green}Starting installation...${reset}"

# setup keyboard layout
echo "${green}-- Setting up keyboard layout.${reset}"
loadkeys us

timedatectl set-ntp true

# format EFI partitions
echo "${green}-- Formatting partitions.${reset}"
lsblk

# format efi partition.
echo "${yellow}Enter linux EFI partition: ${reset}"
read linuxefipartition
mkfs.fat -F 32 $linuxefipartition

# format root partition.
echo "${yellow}Enter root partition: ${reset}"
read rootpartition
mkfs.ext4 $rootpartition

# mounting partitons
echo "${green}-- Mounting partitons.${reset}"
mkdir /mnt/boot
mount $rootpartition /mnt
mount $linuxefipartition /mnt/boot

# -------------------------------------------------------------------------------------------------------------

# install linux system and essentials.
echo "${green}-- Install linux system and essentials.${reset}"
basestrap /mnt base base-devel runit elogind-runit linux-lts linux-firmware neovim curl git dosfstools

# generate fstab
echo "${green}-- Generate fstab.${reset}"
fstabgen -U /mnt >> /mnt/etc/fstab

# move installer to new system
sed '1,/^#new-system-config$/d' arch-installer.sh > /mnt/installer.sh
chmod +x /mnt/installer.sh

# go to system
echo "${green}-- Move to new system.${reset}"
artix-chroot /mnt
./installer.sh
exit

#new-system-config

# set local time zone
echo "${green}-- Set time zone.${reset}"
ln -sf /usr/share/zoneinfo/Asia/Colombo /etc/localtime

# update hardware clock
echo "${green}-- Update hardware clock.${reset}"
hwclock --systohc

# set system language
echo "${green}-- Set system language.${reset}"
sed '/en_US.UTF-8 UTF-8/s/^#//' -i /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

# crate hostname
echo "${green}-- Set system hostname.${reset}"
echo "${yellow}Pick a hostname: ${reset}"
read hostname
echo $hostname >> /etc/hostname

# set hosts
echo "${green}-- Setup system hostfile.${reset}"
echo -e "\n127.0.0.1    localhost\n::1          localhost\n127.0.0.1    desktop.localdomain $hostname" >> /etc/hosts

# install bootloader and relevent packages
echo "${green}-- Install bootloader and relevent packages.${reset}"
pacman --noconfirm -S grub os-prober ntfs-3g

# choosing dual boot or single boot
read -p "Do you wish to dualboot? [y/n]" answer
if [[ $answer = y ]] ; then
     # mounting windows efi
     echo "${green}-- Mounting windows EFI.${reset}"
     mkdir /boot/efi
     lsblk
     echo "${yellow}Enter windows EFI partition: ${reset}"
     read winefipartition
     mount $winefipartition /boot/efi
fi

# enable os-prober
echo -e "\n# Enable os-prober\nGRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
os-prober

# install grub on system
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# generate grub conf
grub-mkconfig -o /boot/grub/grub.cfg

# set root password
echo "${green}-- Set root user password.${reset}"
passwd

# install system packages
echo "${green}-- Install system packages.${reset}"
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop xcompmgr \
     mpv zathura zathura-pdf-mupdf firefox \
     xclip zip unzip unrar p7zip xdotool \
     papirus-icon-theme sxhkd zsh arc-gtk-theme \
     networkmanager networkmanager-runit

# starting networkmanager.
echo "${green}-- Starting network manager${reset}"
ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/

#  setting up sudoers file.
echo "${green}-- Setting up sudoers file.${reset}"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# ------------------------------------------------------------------------------------------------------------------

# creating new user.
echo "${green}-- Creating new user.${reset}"
echo "${yellow}Enter Username: ${reset}"
read username
echo "${yellow}Enter Password: ${reset}"
passwd
useradd -m -G wheel -s /bin/bash $username
exit
