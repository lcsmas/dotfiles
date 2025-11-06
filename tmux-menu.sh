#!/usr/bin/zsh -i

# Capture the current working directory
ORIGINAL_PWD="$PWD"

# Run Ink (React) tmux menu with the original directory
cd ~/dotfiles/tmux-menu && bun index.tsx "$ORIGINAL_PWD"
