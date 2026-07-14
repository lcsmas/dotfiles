# ZSH setup
export ZSH="$HOME/.oh-my-zsh"
export EDITOR="nvim"

source $HOME/.zshenv

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
export PATH="$HOME/dotfiles/bin:$PATH"

# Ensure the versioned git hooks are active in the dotfiles repo (core.hooksPath
# is local config, so it must be re-applied per machine). Cheap idempotent check.
if [ -d ~/dotfiles/.git ] && [ -d ~/dotfiles/bin/hooks ]; then
    if [ "$(git -C ~/dotfiles config core.hooksPath 2>/dev/null)" != "bin/hooks" ]; then
        git -C ~/dotfiles config core.hooksPath bin/hooks
    fi
fi

# Secrets (lazy cache): if plaintext ~/.zsh_secret exists, source it (fast path,
# no 1Password prompt). Otherwise decrypt .zsh_secret.age using the age key from
# 1Password, cache the plaintext to ~/.zsh_secret (chmod 600, gitignored), and
# source it. First shell after a reboot/lock may prompt once for 1Password.
if [ -f ~/.zsh_secret ]; then
    source ~/.zsh_secret
elif [ -f ~/dotfiles/.zsh_secret.age ] && command -v age >/dev/null 2>&1 && command -v op >/dev/null 2>&1; then
    if ~/dotfiles/bin/secrets unseal >/dev/null 2>&1; then
        source ~/.zsh_secret
    fi
fi

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
export ELECTRON_OZONE_PLATFORM_HINT=wayland

# Chromium with a persistent remote-debugging port on a DEDICATED profile, so
# tools (chrome-devtools MCP) can attach to a logged-in session without touching
# the everyday Chromium profile. Always Chromium (no Chrome on this machine).
CHROMIUM_DEBUG_PROFILE="$HOME/.config/chromium-debug"
CHROMIUM_DEBUG_PORT="${CHROMIUM_DEBUG_PORT:-9222}"
chromium() {
  /usr/bin/chromium-browser \
    --remote-debugging-port="$CHROMIUM_DEBUG_PORT" \
    --user-data-dir="$CHROMIUM_DEBUG_PROFILE" \
    "$@" >/dev/null 2>&1 &!
}
alias chromium-debug='chromium'
