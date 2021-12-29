#!/usr/bin/env bash

# colors
reset=`tput sgr0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`

DEVICE=/dev/sda
HOSTNAME="rbthl"

WIN_DEVICE="${DEVICE}1"
BOOT_DEVICE="${DEVICE}2"
ROOT_DEVICE="${DEVICE}3"

TIME_ZONE="Asia/Colombo"
LOCALE="en_US.UTF-8"

echo "${magenta}Starting arch installation...${reset}"

# change pacman parallel download to 5
echo "${green}-- Set pacman parallel download.${reset}"
sed '/#ParallelDownloads = 5/c\ParallelDownloads = 5' -i /etc/pacman.conf

# set system clock
echo "${green}-- Set system clock.${reset}"
timedatectl set-ntp true

# format EFI partitions
echo "${green}-- Formatting partitions.${reset}"
lsblk

# format efi partition.
echo "${green}-- Formatting boot partitions.${reset}"
mkfs.fat -F32 "$BOOT_DEVICE"

# format root partition.
echo "${green}-- Formatting root partitions.${reset}"
mkfs.ext4 "$ROOT_DEVICE"

# mounting partitons
echo "${green}-- Mounting partitons.${reset}"
mount "$ROOT_DEVICE" /mnt
mkdir /mnt/boot
mount "$BOOT_DEVICE" /mnt/boot
df
echo && echo "Partitioning is completed.  Press any key to continue..."; read empty

# install linux system and essentials.
echo "${green}-- Installing linux system and essentials.${reset}"
pacstrap /mnt base linux linux-headers linux-firmware base-devel archlinux-keyring git openssh networkmanager bluez bluez-utils bluez-tools grub os-prober ntfs-3g efibootmgr zsh

# generate fstab
echo "${green}-- Generating fstab.${reset}"
genfstab -U /mnt >> /mnt/etc/fstab
echo && echo "Base system is ready. Press any key to continue..."; read empty

# set stage two installer
sed '1,/^#stage-two$/d' archlinux.sh > /mnt/stage-two.sh
chmod +x /mnt/stage-two.sh
arch-chroot /mnt ./stage-two.sh
exit

#stage-two

# colors
reset=`tput sgr0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`

# set time zone
echo "${green}-- Setting system language.${reset}"
ln -sf /usr/share/zoneinfo/"$TIME_ZONE" /etc/localtime
hwclock --systohc
echo && echo "Time zone is updated. Press any key to continue..."; read empty

# set system locale
echo "${green}-- Setting system locale.${reset}"
sed '/#en_US.UTF-8 UTF-8/c\en_US.UTF-8 UTF-8' -i /etc/locale.gen
locale-gen
echo "LANG="$LOCALE"" > /etc/locale.conf
echo && echo "System locale is updated. Type any key to continue."; read empty

# crate hostname
echo "${green}-- Setting system hostname($HOSTNAME).${reset}"
echo "$HOSTNAME" > /etc/hostname
echo && echo "Hostname($HOSTNAME) is updated. Type any key to continue."; read empty

# crate hosts
echo "${green}-- Setting system hosts file.${reset}"
cat > /etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $HOSTNAME.localdomain     $HOSTNAME
HOSTS
echo && echo "System hosts file is updated. Type any key to continue."; read empty

# set root password
echo "${green}-- Setting root user password.${reset}"
passwd

# install services and enable services
echo "${green}-- Installing services.${reset}"
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
sed -i '/#AutoEnable=false/c\AutoEnable=true' /etc/bluetooth/main.conf
echo && echo "Services are installed and enabled. Type any key to continue."; read empty

# setting up sudoers file.
echo "${green}-- Setting up sudoers file.${reset}"
sed -i '/# %wheel ALL=(ALL) ALL/c\%wheel ALL=(ALL) ALL' /etc/sudoers
cat /etc/sudoers
echo && echo "Sudoers file is updated. Type any key to continue."; read empty

# install grub bootloader and relevent packages
echo "${green}-- Installing grub bootloader and relevent packages.${reset}"
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

# choosing dual boot or single boot
read -p "${yellow}Do you wish to dualboot? [y/n]${reset}" answer
if [[ $answer = y ]] ; then
     # enable os-prober
     echo -e "\n# Disable os-prober\nGRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
     
     # mount windows efi
     mkdir /boot/winefi
     mount "$WIN_DEVICE" /boot/winefi
fi

# generate grub conf
grub-mkconfig -o /boot/grub/grub.cfg
echo && echo "Bootloader is installed. Type any key to continue."; read empty

# creating new user.
echo "${green}-- Creating new user.${reset}"
echo "${yellow}Enter Username: ${reset}"; read USERNAME
useradd -m -G wheel,power,storage,audio,video,optical -s /bin/sh "$USERNAME"
passwd "$USERNAME"
echo && echo "New user is created. Type any key to continue."; read empty

# install packages
echo "${green}-- Installing utility packages.${reset}"
pacman -Sy
pacman -S --noconfirm xorg xorg-xinit xwallpaper scrot python-pywal firefox chromium github-cli neovim alacritty \
	zip unzip unrar p7zip zsh rsync rofi udisks2 ueberzug htop pulseaudio pulseaudio-alsa pulseaudio-bluetooth \
	pulseaudio-jack mesa xf86-video-intel vulkan-intel powertop libinput zathura zathura-pdf-mupdf papirus-icon-theme \
	picom sxhkd pamixer ranger sxiv mpv libnotify dunst highlight wmctrl deepin-gtk-theme
echo && echo "Utility packages are installed. Type any key to continue."; read empty

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
echo && echo "Window manager is installed. Type any key to continue."; read empty

# set stage three installer
stage_three_path=/home/"$USERNAME"/stage-three.sh
sed '1,/^#stage-three$/d' stage-two.sh > $stage_three_path
chown "$USERNAME":"$USERNAME" $stage_three_path
chmod +x $stage_three_path
ls
ls /home/"$USERNAME" -la
echo && echo "Script is ready. Type any key to continue."; read empty
su -c $stage_three_path -s /bin/sh "$USERNAME"
exit

#stage-three

# colors
reset=`tput sgr0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`

# install dotfiles
echo "${green}-- Installing dotfiles.${reset}"
git clone --bare https://github.com/nipunravisara/dots.git $HOME/.dotfiles
ls -la
echo && echo "Dotfiles are cloned. Type any key to continue."; read empty

echo ".dotfiles" >> .gitignore
ls -la
echo && echo "Gitignore is added. Type any key to continue."; read empty

alias dots='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
echo && echo "Alias is added. Type any key to continue."; read empty

dots config --local status.showUntrackedFiles no
dots checkout
ls -la
echo && echo "Dotfiles are applied. Type any key to continue."; read empty

# install oh-my-zsh and chnaging shell to zsh
echo "${green}-- Changing shell to zsh.${reset}"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
echo && echo "Oh-my-zsh is installed. Type any key to continue."; read empty

# install oh-my-zsh extentions
echo "${green}-- Install oh-my-zsh extentions.${reset}"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
echo && echo "Oh-my-zsh extentions are installed. Type any key to continue."; read empty

# install vimplug
echo "${green}-- Installing vimplug.${reset}"
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
       https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
echo && echo "Vimplug is installed. Type any key to continue."; read empty

# install ranger icons
echo "${green}-- Install ranger icons.${reset}"
git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons
echo && echo "Ranger icons are installed. Type any key to continue."; read empty

# create folders
cd $HOME
echo "${green}-- Create folders.${reset}"
mkdir -p ~/Documents ~/Developments ~/Pictures/Wallpapers ~/Videos
ls -la
echo && echo "Folders are created. Type any key to continue."; read empty

# download wallpaper
echo "${green}-- Download wallpaper.${reset}"
curl -o ~/Pictures/Wallpapers/Green-leaves.jpeg https://images.pexels.com/photos/1072179/pexels-photo-1072179.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260
echo && echo "Wallpaper is downloaded. Type any key to continue."; read empty

# remove unwated files
echo "${green}-- Cleaning and linking.${reset}"
ls -la
rm -rf ~/.zshrc ~/.zsh_history ~/.bash_logout ~/.bash_profile ~/.bashrc ~/.shell.pre-oh-my-zsh ~/.zcompdump*
ln -s ~/.config/x11/xinitrc .xinitrc
ln -s ~/.config/x11/Xresources .Xresources
ln -s ~/.config/zsh/zprofile .zprofile
ln -s ~/.config/zsh/zshrc .zshrc
ls -la
echo && echo "Home dir is cleanned. Type any key to continue."; read empty

echo "${magenta}-- Installation Completed, Restart to use your system. --${reset}"
echo "Press any key to exit."; read empty
chsh -s $(which zsh)

exit
