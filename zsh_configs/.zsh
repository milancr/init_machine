# p10k config
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Path
export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="robbyrussell"

# User configuration
zstyle ':omz:update' mode auto
COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
plugins=(git aws dirhistory docker docker-compose dotenv fzf golang 
    nvm pep8 pip pylint zsh_codex zsh-autosuggestions zsh-syntax-highlighting)

bindkey '^X' create_completion # Create completion for zsh_codex
source $ZSH/oh-my-zsh.sh
export LANG=en_US.UTF-8

# Completion enhancements
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Go 
export GOROOT="$(brew --prefix golang)/libexec"
export GOPATH="${HOME}/go"
export PATH="${PATH}:${GOROOT}/bin:${GOPATH}/bin"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/zsh_completion" ] && \. "$NVM_DIR/zsh_completion"  # This loads nvm zsh_completion

# Aliases
alias zshconfig="vim ~/.zshrc"
alias vim="nvim"
alias cat="bat"
alias lzg='lazygit'
alias lzd='lazydocker'
alias ll='eza -lah --git --icons --group-directories-first --time-style=long-iso'
alias spot='spotify_player'