# enable arch repos
echo "${green}Enable arch repos.${reset}"
pacman -Sy
echo -e "\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n\n[community]\nInclude = /etc/pacman.d/mirrorlist-arch\n" >> /etc/pacman.conf
pacman-key --populate archlinux

# install packages
echo "${green}Install package${reset}"
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop \
        sxiv mpv zathura zathura-pdf-mupdf xclip zip unzip unrar p7zip zsh rsync firefox libnotify dunst \
        bspwm sxhkd pamixer

