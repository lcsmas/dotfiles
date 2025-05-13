#!/bin/bash

set -e

echo "Starting Fedora setup script..."

sudo dnf update -y

choose_wm() {
  while true; do
    echo "Which window manager would you like to install?"
    echo "1) Sway"
    echo "2) Hyprland"
    echo "3) Both"
    echo "4) None"
    read -p "Enter your choice (1-4): " wm_choice
    
    case $wm_choice in
      1)
        echo "Installing Sway..."
        sudo dnf install -y sway
        return
        ;;
      2)
        echo "Installing Hyprland..."
        sudo dnf install -y hyprland
        return
        ;;
      3)
        echo "Installing both Sway and Hyprland..."
        sudo dnf install -y sway hyprland
        return
        ;;
      4)
        echo "Skipping window manager installation..."
        return
        ;;
      *)
        echo "Invalid choice. Please enter a number between 1 and 4."
        echo ""
        ;;
    esac
  done
}

choose_wm

sudo dnf install -y pipewire wireplumber tmux git wget curl gcc clang make fzf neovim python3-neovim zsh firefox fd-find nodejs socat flameshot cargo python3-pip chromium rofi-wayland thunar waybar

sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty

sudo dnf copr enable atim/lazygit -y
sudo dnf install -y lazygit

sudo dnf install -y fedora-workstation-repositories
if ! sudo dnf config-manager setopt google-chrome.enabled=1 || ! sudo dnf install -y google-chrome-stable; then
  echo "Warning: Failed to install Google Chrome. Continuing with setup..."
fi

sudo npm install -g tldr yarn

if [ ! -d ~/.nvm ]; then
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
fi

if [ ! -d ~/.tmux/plugins/tpm ]; then
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

if [ ! -d ~/.config/nvim ]; then
	git clone https://github.com/lcsmas/nvim-config ~/.config/nvim
fi

if [ ! -d ~/dotfiles ]; then
	git clone https://www.github.com/lcsmas/dotfiles ~/dotfiles
	cd ~/dotfiles
	DOTFILES=$(ls -la | grep -v '^d' | awk '{ print $9 }' | grep -v '^$' | grep '^\.' | grep -v 'example$' | grep -v '.gitignore' | grep -v '.bashrc')
	DOTFILE_DIR=$(pwd)

	for file in $DOTFILES; do
			ln -sf $DOTFILE_DIR/$file ~/$file
			echo "Created symlink for $file"
	done

	mkdir -p ~/.local/bin/
	ln -sf $DOTFILE_DIR/tmux-sessionizer.sh ~/.local/bin/tmux-sessionizer.sh

	ln -sf $DOTFILE_DIR/sway ~/.config
	ln -sf $DOTFILE_DIR/swaylock ~/.config
fi


# Install ohmyzsh, using existing .zshrc
# Prevents script exiting because of the error concerning the plugins in .zshrc that are not installed yet
ZSH_PLUGINS_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
set +e
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc
set -e

if [ ! -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]; then
	git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_PLUGINS_DIR/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_PLUGINS_DIR/zsh-vi-mode" ]; then
	git clone https://github.com/jeffreytse/zsh-vi-mode "$ZSH_PLUGINS_DIR/zsh-vi-mode"
fi

