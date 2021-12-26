#!/usr/bin/env bash

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

echo "${green}Starting arch installation...${reset}"

# setup keyboard layout
echo "${green}-- Setting up keyboard layout.${reset}"
loadkeys us

# set system clock
echo "${green}-- Set system clock.${reset}"
timedatectl set-ntp true

# format EFI partitions
echo "${green}-- Formatting partitions.${reset}"
lsblk

# format efi partition.
echo "${yellow}Enter linux EFI partition: ${reset}"
read linuxefipartition
mkfs.fat -F32 $linuxefipartition

# format root partition.
echo "${yellow}Enter root partition: ${reset}"
read rootpartition
mkfs.ext4 $rootpartition

# mounting partitons
echo "${green}-- Mounting partitons.${reset}"
mount $rootpartition /mnt
mkdir /mnt/boot
mount $linuxefipartition /mnt/boot
df

# install linux system and essentials.
echo "${green}-- Install linux system and essentials.${reset}"
pacstrap /mnt base linux linux-firmware net-tools networkmanager openssh vi base-devel neovim curl git

# generate fstab
echo "${green}-- Generate fstab.${reset}"
genfstab -U /mnt >> /mnt/etc/fstab

# set stage two installer
sed '1,/^#stage-two$/d' arch-installer.sh > /mnt/stage-two.sh
chmod +x /mnt/stage-two.sh

# go to system
echo "${green}-- Move to new system.${reset}"
arch-chroot /mnt ./stage-two.sh
exit

#stage-two

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`


# set system language
echo "${green}-- Set system language.${reset}"
sed '/en_US.UTF-8 UTF-8/s/^#//' -i /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

# set local time zone
echo "${green}-- Set time zone.${reset}"
ln -sf /usr/share/zoneinfo/Asia/Colombo /etc/localtime

# update hardware clock
echo "${green}-- Update hardware clock.${reset}"
hwclock --systohc --utc

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
pacman --noconfirm -S grub os-prober ntfs-3g efibootmgr


# install grub on system
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

# choosing dual boot or single boot
read -p "${yellow}Do you wish to dualboot? [y/n]${reset}" answer
if [[ $answer = y ]] ; then
     
     # enable os-prober
     echo -e "\n# Enable os-prober\nGRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

     # mounting windows efi
     echo "${green}-- Mounting windows EFI.${reset}"
     mkdir /boot/winefi

     lsblk
     
     echo "${yellow}Enter windows EFI partition: ${reset}"
     read winefipartition
     mount $winefipartition /boot/winefi
fi

# generate grub conf
grub-mkconfig -o /boot/grub/grub.cfg

# setting up sudoers file.
echo "${green}-- Setting up sudoers file.${reset}"
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# install packages
echo "${green}-- Install package${reset}"
pacman -Sy
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop xwallpaper scrot python-pywal \
	xclip zip unzip unrar p7zip zsh rsync rofi udisks2 ueberzug htop pulseaudio pulseaudio-alsa pulseaudio-bluetooth networkmanager \
	pulseaudio-jack mesa xf86-video-intel vulkan-intel bluez bluez-utils bluez-tools pulseaudio-bluetooth powertop libinput \
	picom sxhkd pamixer ranger sxiv mpv zathura zathura-pdf-mupdf firefox firefox-developer-edition libnotify dunst alacritty highlight wmctrl deepin-gtk-theme

# install window manager
echo "${green}-- Select a window manager to install.${reset}"
options=("Herbstluftwm" "BSPWM" "Skip, Install manually")
select opt in "${options[@]}"
do
    case $opt in
        "Herbstluftwm")
            echo "${green}-- Installing $opt.${reset}"
            pacman -S --noconfirm herbstluftwm
            break
            ;;
        "BSPWM")
            echo "${green}-- Installing $opt.${reset}"
            pacman -S --noconfirm bspwm
            break
            ;;
        "Skip, Install manually")
            echo "${yellow}-- Skipping wm install.${reset}"
            break
            ;;
        *) echo "${yellow}invalid option $REPLY, Try again.${reset}";;
    esac
done

# starting networkmanager.
echo "${green}-- Starting network manager${reset}"
systemctl enable NetworkManager.service 

# starting bluetooth.
echo "${green}-- Starting bluetooth${reset}"
sudo systemctl enable bluetooth.service
sed '250iAutoEnable=true' /etc/bluetooth/main.conf

# set root password
echo "${green}-- Set root user password.${reset}"
passwd

# creating new user.
echo "${green}-- Creating new user.${reset}"
echo "${yellow}Enter Username: ${reset}"
read username
useradd -m -G wheel,power,storage,audio,video,optical -s /bin/zsh $username
passwd $username

# set stage three installer
stage_three_path=/home/$username/stage-three.sh
sed '1,/^#stage-three$/d' stage-two.sh > $stage_three_path
chown $username:$username $stage_three_path
chmod +x $stage_three_path
su -c $stage_three_path -s /bin/zsh $username
exit

#stage-three

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

# create folders
cd $HOME
echo "${green}-- Create folders.${reset}"
mkdir -p ~/Documents ~/Developments ~/Pictures/Wallpapers ~/Videos

# download wallpaper
echo "${green}-- Download wallpaper.${reset}"
curl -o ~/Pictures/Wallpapers/Green-leaves.jpeg https://images.pexels.com/photos/1072179/pexels-photo-1072179.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260

# install dotfiles
cd $HOME
echo "${green}-- Install dotfiles.${reset}"
git clone --bare https://github.com/nipunravisara/dots.git $HOME/.dotfiles
echo ".dotfiles" >> .gitignore
alias dots='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
dots config --local status.showUntrackedFiles no
dots checkout

# install oh-my-zsh and chnaging shell to zsh
echo "${green}-- Changing shell to zsh.${reset}"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# install oh-my-zsh extentions
echo "${green}-- Install oh-my-zsh extentions.${reset}"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# install ranger icons
echo "${green}-- Install ranger icons.${reset}"
git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons

# remove unwated files
echo "${green}-- Cleaning and linking.${reset}"
rm -rf ~/.zshrc ~/.zsh_history ~/.bash_logout ~/.bash_profile ~/.bashrc ~/.shell.pre-oh-my-zsh ~/.zcompdump*
ln -s ~/.config/x11/xinitrc .xinitrc
ln -s ~/.config/x11/Xresources .Xresources
ln -s ~/.config/zsh/zprofile .zprofile
ln -s ~/.config/zsh/zshrc .zshrc

echo "${green}-- Installation Completed, Restart to use your system. --${reset}"
exit
