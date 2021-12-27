#!/usr/bin/env bash

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

# varibales
DEVICE=/dev/sda
HOSTNAME="rbthl"

WIN_DEVICE="${DEVICE}1"
BOOT_DEVICE="${DEVICE}2"
ROOT_DEVICE="${DEVICE}3"

TIME_ZONE="Asia/Colombo"
LOCALE="en_US.UTF-8"

# set system clock
echo "${green}-- Setting system clock.${reset}"
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
echo && echo "Partitioning completed.  Press any key to continue..."; read empty

# install linux system and essentials.
echo "${green}-- Installing linux system and essentials.${reset}"
pacstrap /mnt base linux linux-headers linux-firmware base-devel archlinux-keyring

# generate fstab
echo "${green}-- Generating fstab.${reset}"
genfstab -U /mnt >> /mnt/etc/fstab
echo && echo "Base system ready. Press any key to continue..."; read empty

# set time zone
echo "${green}-- Setting system language.${reset}"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIME_ZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc --utc
arch-chroot /mnt date
echo && echo "Time zone updated. Press any key to continue..."; read empty

# set system locale
echo "${green}-- Setting system locale.${reset}"
arch-chroot /mnt sed -i "s/#$LOCALE/$LOCALE/g" /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
export LANG="$LOCALE"
echo && echo "System locale updated. Type any key to continue."; read empty

# crate hostname
echo "${green}-- Setting system hostname($HOSTNAME).${reset}"
echo "$HOSTNAME" > /mnt/etc/hostname
echo && echo "Hostname($HOSTNAME) updated. Type any key to continue."; read empty

# crate hosts
echo "${green}-- Setting system hosts file.${reset}"
cat > /mnt/etc/hosts <<HOSTS
127.0.0.1      localhost
::1            localhost
127.0.1.1      $HOSTNAME.localdomain     $HOSTNAME
HOSTS
echo && echo "System hosts file updated. Type any key to continue."; read empty

# set root password
echo "${green}-- Setting root user password.${reset}"
arch-chroot /mnt passwd

# install services and enable services
echo "${green}-- Installing services.${reset}"
arch-chroot /mnt pacman -S git openssh networkmanager bluez bluez-utils
arch-chroot /mnt systemctl start NetworkManager.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl start bluetooth.service
arch-chroot /mnt systemctl enable bluetooth.service
echo && echo "Services installed and enabled. Type any key to continue."; read empty

# setting up sudoers file.
echo "${green}-- Setting up sudoers file.${reset}"
arch-chroot /mnt sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
echo && echo "Sudoers file updated. Type any key to continue."; read empty

# install bootloader and relevent packages
echo "${green}-- Installing bootloader and relevent packages.${reset}"
arch-chroot /mnt pacman --noconfirm -S grub os-prober ntfs-3g efibootmgr

# install grub on system
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

# choosing dual boot or single boot
read -p "${yellow}Do you wish to dualboot? [y/n]${reset}" answer
if [[ $answer = y ]] ; then
     # enable os-prober
     echo -e "\n# Enable os-prober\nGRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub
     
     # mount windows efi
     mkdir /boot/winefi
     mount "$WIN_DEVICE" /boot/winefi
fi

# generate grub conf
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
echo && echo "Bootloader installed. Type any key to continue."; read empty

# creating new user.
echo "${green}-- Creating new user.${reset}"
echo "${yellow}Enter Username: ${reset}"; read USERNAME
arch-chroot /mnt useradd -m -G wheel,power,storage,audio,video,optical -s /bin/sh "$USERNAME"
arch-chroot /mnt passwd "$USERNAME"
echo && echo "New user created. Type any key to continue."; read empty

# install packages
echo "${green}-- Installing utility packages.${reset}"
arch-chroot /mnt pacman -Sy
arch-chroot /mnt pacman -S --noconfirm xorg xorg-xinit xwallpaper scrot python-pywal firefox firefox-developer-edition git \
	xclip zip unzip unrar p7zip zsh rsync rofi udisks2 ueberzug htop pulseaudio pulseaudio-alsa pulseaudio-bluetooth networkmanager \
	pulseaudio-jack mesa xf86-video-intel vulkan-intel bluez bluez-utils bluez-tools pulseaudio-bluetooth powertop libinput \
	picom sxhkd pamixer ranger sxiv mpv zathura zathura-pdf-mupdf libnotify dunst alacritty highlight wmctrl deepin-gtk-theme
echo && echo "Utility packages installed. Type any key to continue."; read empty

# install window manager
echo "${green}-- Select a window manager to install.${reset}"
options=("Herbstluftwm" "BSPWM" "Skip, Install manually")
select opt in "${options[@]}"
do
    case $opt in
        "Herbstluftwm")
            echo "${green}-- Installing $opt.${reset}"
            arch-chroot /mnt pacman -S --noconfirm herbstluftwm
            break
            ;;
        "BSPWM")
            echo "${green}-- Installing $opt.${reset}"
            arch-chroot /mnt pacman -S --noconfirm bspwm
            break
            ;;
        "Skip, Install manually")
            echo "${yellow}-- Skipping wm install.${reset}"
            break
            ;;
        *) echo "${yellow}invalid option $REPLY, Try again.${reset}";;
    esac
done
echo && echo "Window manager installed. Type any key to continue."; read empty

# set stage three installer
#stage_three_path=/home/$USERNAME/ricing.sh
#sed '1,/^#ricing$/d' arch.sh > $stage_three_path
#chown $USERNAME:$USERNAME $stage_three_path
#chmod +x $stage_three_path
#ls -la
#echo && echo "Script is ready. Type any key to continue."; read empty
#su -c $stage_three_path -s /bin/bash $USERNAME
#exit

#ricing

# create folders
echo "${green}-- Creating folders.${reset}"
arch-chroot /mnt su "$USERNAME" -c mkdir -p ~/Documents ~/Developments ~/Pictures/Wallpapers ~/Videos
echo && echo "Folders created. Type any key to continue."; read empty

# download wallpaper
echo "${green}-- Downloading wallpaper.${reset}"
arch-chroot /mnt su "$USERNAME" curl -o ~/Pictures/Wallpapers/Green-leaves.jpeg https://images.pexels.com/photos/1072179/pexels-photo-1072179.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260
echo && echo "Wallpaper downloaded. Type any key to continue."; read empty

# install dotfiles
cd $HOME
echo "${green}-- Installing dotfiles.${reset}"
arch-chroot /mnt su "$USERNAME" git clone --bare https://github.com/nipunravisara/dots.git $HOME/.dotfiles
arch-chroot /mnt su "$USERNAME" echo ".dotfiles" >> .gitignore
arch-chroot /mnt su "$USERNAME" alias dots='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
arch-chroot /mnt su "$USERNAME" dots config --local status.showUntrackedFiles no
arch-chroot /mnt su "$USERNAME" dots checkout

# install oh-my-zsh and chnaging shell to zsh
echo "${green}-- Changing shell to zsh.${reset}"
arch-chroot /mnt su "$USERNAME" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# install oh-my-zsh extentions
echo "${green}-- Install oh-my-zsh extentions.${reset}"
arch-chroot /mnt su "$USERNAME" clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
arch-chroot /mnt su "$USERNAME" clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# install ranger icons
echo "${green}-- Install ranger icons.${reset}"
arch-chroot /mnt su "$USERNAME" clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons

# remove unwated files
echo "${green}-- Cleaning and linking.${reset}"
arch-chroot /mnt su "$USERNAME" rm -rf ~/.zshrc ~/.zsh_history ~/.bash_logout ~/.bash_profile ~/.bashrc ~/.shell.pre-oh-my-zsh ~/.zcompdump*
arch-chroot /mnt su "$USERNAME" ln -s ~/.config/x11/xinitrc .xinitrc
arch-chroot /mnt su "$USERNAME" ln -s ~/.config/x11/Xresources .Xresources
arch-chroot /mnt su "$USERNAME" ln -s ~/.config/zsh/zprofile .zprofile
arch-chroot /mnt su "$USERNAME" ln -s ~/.config/zsh/zshrc .zshrc

echo "${green}-- Installation Completed, Restart to use your system. --${reset}"
exit
