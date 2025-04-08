#!/bin/bash

set -e

echo "Starting Fedora setup script..."

sudo dnf update -y
sudo dnf install -y sway pipewire wireplumber tmux git wget curl gcc make fzf neovim python3-neovim zsh firefox fd-find

dnf copr enable -y pgdev/ghostty
dnf install ghostty

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/lcsmas/nvim-config ~/.config/nvim

git clone https://www.github.com/lcsmas/dotfiles
cd dotfiles
DOTFILES=$(ls -la | grep -v '^d' | awk '{ print $9 }' | grep -v '^$' | grep '^\.' | grep -v 'example$' | grep -v '.gitignore' | grep -v '.bashrc')
DOTFILE_DIR=$(pwd)

for file in $DOTFILES; do
		ln -s $DOTFILE_DIR/$file ~/$file
		echo "Created symlink for $file"
done
ln -s $DOTFILE_DIR/tmux-sessionizer.sh ~/.local/bin/tmux-sessionizer.sh

echo "Sudo password is required to change the default shell to zsh."
sudo chsh -s $(which zsh) $USER
echo "Zsh has been installed and set as your default shell."
echo "Please log out and log back in for the changes to take effect."

