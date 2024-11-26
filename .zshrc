# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git pj zsh-vi-mode yarn-autocompletions zsh-autosuggestions)


source $ZSH/oh-my-zsh.sh

export DISPLAY=:0

# export DISPLAY=$(ip route | grep default | awk '{print $3}'):0.0
# export LIBGL_ALWAYS_INDIRECT=0

# export XDG_SESSION_TYPE=x11
# export GDK_BACKEND=x11
# unset WAYLAND_DISPLAY
# export WAYLAND_DISPLAY=wayland-0
# export XDG_RUNTIME_DIR=/tmp/runtime-dir

# export MOZ_X11_EGL=1
# export MOZ_WEBRENDER=0
# export MOZ_ACCELERATED=0

# export XFCE_PANEL_MIGRATE_DEFAULT=true
# export NO_AT_BRIDGE=1
# export QT_X11_NO_MITSHM=1



export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export BROWSER='wslview'

export PATH="$PATH:/opt/nvim/"

# FZF
# Set up fzf key bindings and fuzzy completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ALIASES
source ~/.zsh_aliases

source ~/.custom-function


