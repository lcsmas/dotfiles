# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git pj zsh-vi-mode yarn-autocompletions zsh-autosuggestions)


source $ZSH/oh-my-zsh.sh

export DISPLAY=:0

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export BROWSER='wslview'

export PATH="$PATH:/opt/nvim/:$HOME/.local/share/kotlin-language-server/bin:$HOME/.local/bin"

# FZF
# Set up fzf key bindings and fuzzy completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ENVIROMENT VARIABLES
export ANTHROPIC_API_KEY=
# ALIASES
source ~/.zsh_aliases

source ~/.custom-function


# test
