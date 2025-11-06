#!/bin/bash

selected=$(find ~/ -maxdepth 4 -type d  | fzf)
echo $selected

if [[ -z $selected ]]; then
		exit 0
fi

selected_name=$(basename $selected | sed 's/^\.//')
echo $selected_name


if ! tmux has-session -t=$selected_name 2> /dev/null; then
		tmux new-session -ds $selected_name -c $selected "cd $selected && exec zsh"
fi

tmux switch-client -t $selected_name


