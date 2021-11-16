echo "Starting installation..."

# setup keyboard layout
echo "-- Setting up keyboard layout."
loadkeys us

timedatectl set-ntp true

# format EFI partitions
echo "-- Formatting partitions."
lsblk

# format efi partition.
echo "Enter linux EFI partition: "
read linuxefipartition
mkfs.fat -F32 $linuxefipartition

# format root partition.
echo "Enter root partition: "
read rootpartition
mkfs.ext4 $rootpartition

# mounting partitons
echo "-- Mounting partitons."
mkdir /mnt/boot
mount $rootpartition /mnt
mount $linuxefipartition /mnt/boot

# -------------------------------------------------------------------------------------------------------------

# install linux system and essentials.
echo "-- Install linux system and essentials."
basestrap /mnt base base-devel runit elogind-runit linux-lts linux-firmware neovim curl git dosfstools

# generate fstab
echo "-- Generate fstab."
fstabgen -U /mnt >> /mnt/etc/fstab

#new-system-config

# move installer to new system
sed '1,/^#new-system-config$/d' arch-installer.sh > /mnt/installer.sh
chmod +x /mnt/installer.sh

# go to system
echo "-- Move to new system."
artix-chroot /mnt ./installer.sh
exit

# set local time zone
echo "-- Set time zone."
ln -sf /usr/share/zoneinfo/Asia/Colombo /etc/localtime

# update hardware clock
echo "-- Update hardware clock."
hwclock --systohc

# set system language
echo "-- Set system language."
sed '/en_US.UTF-8 UTF-8/s/^#//' -i /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

# crate hostname
echo "-- Set system hostname."
echo "Pick a hostname: "
read hostname
echo $hostname >> /etc/hostname

# set hosts
echo "-- Setup system hostfile."
echo -e "\n127.0.0.1    localhost\n::1          localhost\n127.0.0.1    desktop.localdomain $hostname" >> /etc/hosts

# install bootloader and relevent packages
echo "-- Install bootloader and relevent packages."
pacman --noconfirm -S grub os-prober ntfs-3g

# choosing dual boot or single boot
read -p "Do you wish to dualboot? [y/n]" answer
if [[ $answer = y ]] ; then
     # mounting windows efi
     echo "-- Mounting windows EFI."
     mkdir /boot/efi
     lsblk
     echo "Enter windows EFI partition: "
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
echo "-- Set root user password."
passwd

# install system packages
echo "-- Install system packages."
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop xcompmgr \
     mpv zathura zathura-pdf-mupdf firefox \
     xclip zip unzip unrar p7zip xdotool \
     papirus-icon-theme sxhkd zsh arc-gtk-theme \
     networkmanager networkmanager-runit

# starting networkmanager.
echo "-- Starting network manager"
ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/

#  setting up sudoers file.
echo "-- Setting up sudoers file."
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# ------------------------------------------------------------------------------------------------------------------

# creating new user.
echo "-- Creating new user."
echo "Enter Username: "
read username
echo "Enter Password: "
read password
passwd $password
useradd -m -G wheel -s /bin/zsh $username