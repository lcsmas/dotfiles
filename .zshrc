# ZSH setup
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

ZSH_THEME="robbyrussell"
plugins=(git zsh-vi-mode yarn zsh-autosuggestions fzf-tab zsh-syntax-highlighting)
[ -f $ZSH/oh-my-zsh.sh ] && source $ZSH/oh-my-zsh.sh

# Key bindings
bindkey -v '^[o' autosuggest-accept
bindkey -v '^o' autosuggest-accept

# NVM setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use  # This loads nvm

# WSL setup
if grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    export DISPLAY=:0
		export BROWSER='wslview'
fi

export PATH="$HOME/.local/share/bob/nvim-bin/:$PATH:/opt/nvim/:$HOME/.local/bin:$HOME/.cargo/bin/"

# Custom scripts setup
source ~/.zsh_aliases
[ -f ~/.zsh_secret ] && source ~/.zsh_secret

# FZF setup
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Man pages with Neovim (uses built-in Man command for best compatibility)
export MANPAGER='nvim +Man!'
export MANWIDTH=999

# Fuzzy man page search (search for man pages by name)
fman() {
    man -k . | fzf --preview="echo {1,2} | sed 's/ (/./' | sed 's/)$//' | xargs -r man | col -bx | bat -l man -p --color=always" | awk '{print $1 "." $2}' | tr -d '()' | xargs -r man
}

# bun completions
[ -s "/home/lmas/.bun/_bun" ] && source "/home/lmas/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# go
export PATH=":/usr/local/go/bin:$HOME/go/bin/:$PATH"



# pnpm
export PNPM_HOME="/home/lmas/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
