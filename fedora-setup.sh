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

sudo dnf install -y pipewire wireplumber tmux git wget curl gcc clang make fzf neovim python3-neovim zsh firefox fd-find nodejs socat flameshot cargo python3-pip

sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty

sudo dnf copr enable atim/lazygit -y
sudo dnf install -y lazygit

sudo dnf install -y fedora-workstation-repositories
# sudo dnf config-manager setopt google-chrome.enabled=1
# sudo dnf install -y google-chrome-stable
sudo dnf install google-chrome-stable --enable repo=google-chrome


npm install -g tldr yarn

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

	mkdir -p ~/.config/sway
	ln -sf $DOTFILE_DIR/sway ~/.config/sway

	mkdir -p ~/.config/swaylock
	ln -sf $DOTFILE_DIR/swaylock ~/.config/swaylock
fi

# Install ohmyzsh, using existing .zshrc
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc

# Install zsh plugins
if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]; then
	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-vi-mode ]; then
	git clone https://github.com/jeffreytse/zsh-vi-mode $ZSH_CUSTOM/plugins/zsh-vi-mode
fi
