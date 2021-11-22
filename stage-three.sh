#system-ricing-config

# colors
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

# install oh-my-zsh and chnaging shell to zsh
echo "${green}Changing shell to zsh.${reset}"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
source ~/.bashrc

# create folders
#cd $HOME
#echo "${green}Create folders.${reset}"
#mkdir -p ~/documents ~/development ~/videos

# installing dotfiles
echo "${green}Installing dotfiles.${reset}"
echo "alias d='/usr/bin/git --git-dir=$HOME/.dots/ --work-tree=$HOME'" >> .zshrc
echo ".dots" >> .gitignore
git clone --bare https://github.com/nipunravisara/dots.git $HOME/.dots
source ~/.zshrc
mv ~/.zshrc ~/.zshrc.back
d checkout
d config --local status.showUntrackedFiles no

echo "${green}Dotfiles successfully installed.${reset}"
