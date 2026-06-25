#!/usr/bin/env bash
# Status line based on oh-my-zsh robbyrussell theme.
# Receives Claude Code session JSON on stdin.

input=$(cat)

# Current directory (basename only, like robbyrussell's %c)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
dirname=$(basename "$cwd")

# Git branch from workspace repo info, falling back to git command
branch=""
git_dirty=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
    branch="$git_branch"
    # Check for uncommitted changes (dirty working tree)
    if ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --quiet 2>/dev/null || \
       ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --cached --quiet 2>/dev/null; then
        git_dirty=1
    fi
fi

# ANSI colors (dimmed in the status bar but kept for structure)
bold_green="\033[1;32m"
bold_red="\033[1;31m"
cyan="\033[0;36m"
bold_blue="\033[1;34m"
red="\033[0;31m"
blue="\033[0;34m"
yellow="\033[0;33m"
reset="\033[0m"

# Arrow: green normally, red if last exit code were non-zero (we always show green here)
printf "${bold_green}➜${reset}  ${cyan}%s${reset}" "$dirname"

# Git info
if [ -n "$branch" ]; then
    printf " ${bold_blue}git:(${red}%s${bold_blue})" "$branch"
    if [ -n "$git_dirty" ]; then
        printf "${blue}) ${yellow}✗${reset}"
    else
        printf "${blue})${reset}"
    fi
fi

printf "\n"
