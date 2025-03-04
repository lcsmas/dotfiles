#!/bin/bash

set -e

echo "Starting Fedora setup script..."

sudo dnf update -y
sudo dnf install -y wayland sway pipewire wireplumber tmux git wget curl gcc make fzf neovim python3-neovim zsh firefox

dnf copr enable pgdev/ghostty
dnf install ghostty

git clone https://www.github.com/lcsmas/dotfiles
cd dotfiles
DOTFILES=$(ls -la | grep -v '^d' | awk '{ print $9 }' | grep -v '^$' | grep '^\.' | grep -v 'example$')
DOTFILE_DIR=$(pwd)

for file in $DOTFILES; do
		ln -s $DOTFILE_DIR/$file ~/$file
		echo "Created symlink for $file"
done

echo "Sudo password is required to change the default shell to zsh."
sudo chsh -s $(which zsh) $USER
echo "Zsh has been installed and set as your default shell."
echo "Please log out and log back in for the changes to take effect."

