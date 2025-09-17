#!/usr/bin/zsh -i

selected=$(printf "%b" "yarn dev\n~/dev/workspace/scripts/custom-go-release.sh\nnvm use 18\nreboot\n" | fzf --reverse --prompt='Select command: ')

if [[ $selected == '' ]]; then 
  exit 0
fi

tmux neww -n $selected "zsh -ic '$selected'; zsh -i"

