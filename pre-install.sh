# enable arch repos
echo "${green}Enable arch repos.${reset}"
echo -e "\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n\n[community]\nInclude = /etc/pacman.d/mirrorlist-arch\n" >> /etc/pacman.conf
pacman -Sy
pacman-key --populate archlinux

# install packages
echo "${green}Install package${reset}"
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop \
        sxiv mpv zathura zathura-pdf-mupdf xclip zip unzip unrar p7zip zsh rsync firefox libnotify dunst \
        bspwm sxhkd pamixer

# finish installation
echo "Installation finished."

#system-ricing-config

# create folders
cd $HOME
echo "${green}Create folders.${reset}"
mkdir -p ~/documents ~/development ~/videos

# clone dotfiles
echo "${green}Clone dotfiles.${reset}"
git clone --separate-git-dir=$HOME/.dotfiles https://github.com/anandpiyer/.dotfiles.git tmpdotfiles
rsync --recursive --verbose --exclude '.git' tmpdotfiles/ $HOME/
rm -r tmpdotfiles
