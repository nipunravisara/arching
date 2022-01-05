#!/usr/bin/env bash

# colors
reset=`tput sgr0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`

DEVICE=/dev/nvme0n1

BOOT_DEVICE="${DEVICE}p4"
ROOT_DEVICE="${DEVICE}p5"

echo "${magenta}Starting arch installation...${reset}"

# change pacman parallel download to 5
echo "${green}-- Set pacman parallel download.${reset}"
sed '/#ParallelDownloads = 5/c\ParallelDownloads = 5' -i /etc/pacman.conf

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
basestrap /mnt base linux-lts runit elogind-runit artix-archlinux-support linux-headers linux-firmware base-devel archlinux-keyring git openssh networkmanager networkmanager-runit bluez bluez-runit bluez-utils grub os-prober ntfs-3g efibootmgr zsh

# generate fstab
echo "${green}-- Generating fstab.${reset}"
fstabgen -U /mnt >> /mnt/etc/fstab
echo && echo "Base system is ready. Press any key to continue..."; read empty

# set stage two installer
sed '1,/^#stage-two$/d' artixlinux.sh > /mnt/stage-two.sh
chmod +x /mnt/stage-two.sh
artix-chroot /mnt ./stage-two.sh
exit

#stage-two

# colors
reset=`tput sgr0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`

DEVICE=/dev/nvme0n1
WIN_DEVICE="${DEVICE}p1"

HOSTNAME="rbthl"

TIME_ZONE="Asia/Colombo"
LOCALE="en_US.UTF-8"

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
echo && echo "Root user password is saved. Type any key to continue."; read empty

# enable services
echo "${green}-- Enabling services.${reset}"
ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
sed -i '/#AutoEnable=false/c\AutoEnable=true' /etc/bluetooth/main.conf
echo && echo "Services are enabled. Type any key to continue."; read empty

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
echo && echo "User created. Type any key to continue."; read empty

# setting no passwd to sudoers file.
echo "${green}-- Setting up sudoers file.${reset}"
sed -i '/# %wheel ALL=(ALL) NOPASSWD: ALL/c\%wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers
cat /etc/sudoers
echo && echo "Sudoers file is updated. Type any key to continue."; read empty

# install yay
echo "${green}-- Installing aur helper(yay).${reset}"
git clone https://aur.archlinux.org/yay-git.git /opt/yay-git
echo && echo "Aur cloned. Type any key to continue."; read empty
chown -R "$USERNAME":"$USERNAME" /opt/yay-git
echo && echo "Permission changed. Type any key to continue."; read empty
cd /opt/yay-git/; su "$USERNAME" -c 'makepkg -si --syncdeps --install --needed --noconfirm'; cd /
echo && echo "Aur helper is installed. Type any key to continue."; read empty

# setting up sudoers file file.
echo "${green}-- Setting up sudoers file.${reset}"
sed -i '/%wheel ALL=(ALL) NOPASSWD: ALL/c\# %wheel ALL=(ALL) NOPASSWD: ALL' /etc/sudoers
sed -i '/# %wheel ALL=(ALL) ALL/c\%wheel ALL=(ALL) ALL' /etc/sudoers
cat /etc/sudoers
echo && echo "Sudoers file is updated. Type any key to continue."; read empty

# enable arch repos
echo "${green}-- Enabling arch repos.${reset}"
pacman -Sy
echo -e "\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n\n[community]\nInclude = /etc/pacman.d/mirrorlist-arch\n" >> /etc/pacman.conf
pacman-key --populate archlinux
echo && echo "Arch repos acre configured. Type any key to continue."; read empty

# install packages in official repos
echo "${green}-- Installing utility packages.${reset}"
su "$USERNAME" -c 'yay -Sy'
echo && echo "Yay synced. Type any key to continue."; read empty
pacman -Qqm
echo && echo "Installed form yay. Type any key to continue."; read empty
su "$USERNAME" -c 'yay -S libxft-bgra'
echo && echo "Yay synced. Type any key to continue."; read empty
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop xwallpaper nodejs yarn \
	scrot python-pywal xclip zip unzip unrar p7zip zsh rsync rofi udisks2 ueberzug pulseaudio pulseaudio-alsa pulseaudio-bluetooth \
	pulseaudio-jack pulseaudio-bluetooth mesa xf86-video-intel vulkan-intel powertop libinput sxhkd pamixer ranger code \
	chromium firefox neovim htop alacritty mpv sxiv zathura zathura-pdf-mupdf libnotify dunst  highlight wmctrl deepin-gtk-theme papirus-icon-theme
yay -Sy
pacman -S --noconfirm breezex-cursor-theme pfetch picom-git
echo && echo "Utility packages are installed. Type any key to continue."; read empty

# install window manager
echo "${green}-- Select a window manager to install.${reset}"
options=("Herbstluftwm" "BSPWM" "DWM" "Skip, Install manually")
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
        "DWM")
            echo "${green}-- Installing $opt.${reset}"
            git clone https://github.com/nipunravisara/dwm.git /home/$USERNAME/dwm
	    git clone https://github.com/nipunravisara/dwmblocks.git /home/$USERNAME/dwmblocks
	    sudo -S make clean install -C /home/$USERNAME/dwm
	    sudo -S make clean install -C /home/$USERNAME/dwmblocks
	    echo && echo "DWM is installed. Type any key to continue."; read empty
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

echo ".dotfiles" >> $HOME/.gitignore
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
curl -o ~/Pictures/Wallpapers/Nissan-skyline.jpeg https://images.hdqwalls.com/wallpapers/nissan-gtr-r34-anime-girl-5k-dn.jpg
echo && echo "Wallpaper is downloaded. Type any key to continue."; read empty

# remove unwated files
echo "${green}-- Cleaning and linking.${reset}"
ls -la
rm -rf ~/.zsh_history ~/.bash_logout ~/.bash_profile ~/.bashrc ~/.shell.pre-oh-my-zsh ~/.zcompdump* ~/.zshrc.pre-oh-my-zsh
ls -la
echo && echo "Home dir is cleanned. Type any key to continue."; read empty

echo "${magenta}-- Installation Completed, Restart to use your system. --${reset}"
echo "Press any key to exit."; read empty
chsh -s $(which zsh)
exit
