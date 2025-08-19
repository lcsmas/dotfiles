#!/bin/zsh -i

command=$(history | awk '{$1=""; sub(/^ /, ""); print}' | fzf --scheme=history)

eval "$command";
