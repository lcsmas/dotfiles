# ZSH setup
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

ZSH_THEME="robbyrussell"
plugins=(git zsh-vi-mode yarn zsh-autosuggestions)
[ -f $ZSH/oh-my-zsh.sh ] && source $ZSH/oh-my-zsh.sh

# Key bindings
bindkey '^[o' autosuggest-accept

# NVM setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm

# WSL setup
if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    export DISPLAY=:0
		export BROWSER='wslview'
fi

# Path setup
export PATH="$PATH:/opt/nvim/:$HOME/.local/share/kotlin-language-server/bin:$HOME/.local/bin"

# Custom scripts setup
source ~/.zsh_aliases
source ~/.custom-function.sh
[ -f ~/.zsh_secret ] && source ~/.zsh_secret

# FZF setup
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


