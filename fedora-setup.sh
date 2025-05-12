#!/bin/bash

set -e

echo "Starting Fedora setup script..."

sudo dnf update -y
sudo dnf install -y sway pipewire wireplumber tmux git wget curl gcc make fzf neovim python3-neovim zsh firefox fd-find nodejs socat flameshot cargo python3-pip

sudo dnf copr enable -y pgdev/ghostty
sudo dnf install -y ghostty

sudo dnf copr enable atim/lazygit -y
sudo dnf install -y lazygit

sudo dnf install -y fedora-workstation-repositories
sudo dnf config-manager setopt google-chrome.enabled=1
sudo dnf install -y google-chrome-stable

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
	cd dotfiles
	DOTFILES=$(ls -la | grep -v '^d' | awk '{ print $9 }' | grep -v '^$' | grep '^\.' | grep -v 'example$' | grep -v '.gitignore' | grep -v '.bashrc')
	DOTFILE_DIR=$(pwd)

	for file in $DOTFILES; do
			ln -sf $DOTFILE_DIR/$file ~/$file
			echo "Created symlink for $file"
	done

	mkdir -p ~/.local/bin/
	ln -sf $DOTFILE_DIR/tmux-sessionizer.sh ~/.local/bin/tmux-sessionizer.sh
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
