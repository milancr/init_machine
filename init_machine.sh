#!/bin/bash

# Set strict mode
set -euo pipefail
IFS=$'\n\t'

# Dry run flag
DRY_RUN=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
done

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define log file
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/install_log_$(date +%Y%m%d_%H%M%S).txt"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function for colored logging
log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN]${NC} $message"
    else
        echo -e "$message" | tee -a "$LOG_FILE"
    fi
}

# Start logging
log "Starting installation script"
log "Log file: $LOG_FILE"
if $DRY_RUN; then
    log "Running in dry run mode. No changes will be made to your system."
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to ask yes/no questions
ask_yes_no() {
    local question="$1"
    while true; do
        echo -ne "${BOLD}${question}${NC} ${CYAN}(y/n):${NC} "
        read yn
        case $yn in
            [Yy]* ) 
                if $DRY_RUN; then
                    log "${GREEN}[DRY RUN] User selected: Yes${NC}"
                fi
                return 0
                ;;
            [Nn]* ) 
                if $DRY_RUN; then
                    log "${RED}[DRY RUN] User selected: No${NC}"
                fi
                return 1
                ;;
            * ) echo -e "${YELLOW}Please answer yes or no.${NC}";;
        esac
    done
}

# Progress bar function
progress_bar() {
    if ! $DRY_RUN; then
        local duration=${1}
        local steps=$(($duration * 2))
        local step_duration=0.5
        already_done() { for ((done = 0; done < $elapsed; done++)); do printf "▇"; done; }
        remaining() { for ((remain = $elapsed; remain < $steps; remain++)); do printf " "; done; }
        percentage() { printf "| %s%%" $(((($elapsed) * 100) / ($steps) * 100 / 100)); }
        clean_line() { printf "\r"; }

        for ((elapsed = 1; elapsed <= $steps; elapsed++)); do
            already_done
            remaining
            percentage
            sleep $step_duration
            clean_line
        done
        clean_line
    fi
}

# Function to install Homebrew
install_homebrew() {
    if ! command_exists brew; then
        log "Installing Homebrew..."
        if ! $DRY_RUN; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                log "Failed to install Homebrew"
                exit 1
            }
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
            progress_bar 10
        fi
    else
        log "Homebrew is already installed."
    fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "Installing Oh My Zsh..."
        if ! $DRY_RUN; then
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
                log "Failed to install Oh My Zsh"
                exit 1
            }
            progress_bar 5
        fi
    else
        log "Oh My Zsh is already installed."
    fi
}

# Function to install Homebrew packages with description
install_brew_package() {
    local package_type=$1
    local package_name=$2
    local description=$3
    if ask_yes_no "Do you want to install ${BOLD}${BLUE}$package_name${NC}? (${MAGENTA}$description${NC})"; then
        log "Installing $package_type ${BOLD}${BLUE}$package_name${NC}..."
        if ! $DRY_RUN; then
            if [ "$package_type" = "cask" ]; then
                brew install --cask "$package_name" || log "${RED}Failed to install cask $package_name${NC}"
            else
                brew install "$package_name" || log "${RED}Failed to install formula $package_name${NC}"
            fi
            progress_bar 3
        else
            log "${YELLOW}[DRY RUN] Would install $package_type $package_name${NC}"
        fi
    else
        log "${YELLOW}Skipping installation of $package_name${NC}"
    fi
}

generate_command_docs() {
    local doc_file="$HOME/Documents/installed_commands.md"

    {
        echo "# Installed Commands and Tools"
        echo
        echo "This document lists all the tools installed by the setup script, along with brief descriptions and basic usage information."
        echo

        echo "## Homebrew Formulae"
        echo
        for i in "${!formulas[@]}"; do
            local formula="${formulas[$i]}"
            local description="${formula_descriptions[$i]}"
            echo "### ${formula}"
            echo
            echo "${description}"
            echo
            echo "Basic usage:"
            echo "\`\`\`"
            echo "$ ${formula} --help"
            echo "\`\`\`"
            echo
        done

        echo "## Homebrew Casks (GUI Applications)"
        echo
        for i in "${!casks[@]}"; do
            local cask="${casks[$i]}"
            local description="${cask_descriptions[$i]}"
            echo "### ${cask}"
            echo
            echo "${description}"
            echo
            echo "This is a GUI application. You can find it in your Applications folder or launch it from Spotlight."
            echo
        done

        echo "## Additional Resources"
        echo
        echo "- Homebrew Documentation: https://docs.brew.sh"
        echo "- Man pages: Use \`man [command]\` in the terminal for detailed documentation on CLI tools."
        echo "- Official websites: Refer to the URLs provided in the descriptions for more information on each tool."
    } >"$doc_file"

    log "Command documentation generated at $doc_file"
}

# Main installation process
log "${GREEN}Starting installation process...${NC}"

# Install Homebrew
if ask_yes_no "Do you want to install Homebrew?"; then
    if ! $DRY_RUN; then
        install_homebrew
    else
        log "[DRY RUN] Would install Homebrew"
    fi
else
    if ! command_exists brew; then
        log "Homebrew is required for many components of this setup. Are you sure you want to skip it?"
        if ask_yes_no "Install Homebrew anyway?"; then
            if ! $DRY_RUN; then
                install_homebrew
            else
                log "[DRY RUN] Would install Homebrew"
            fi
        else
            log "Skipping Homebrew installation. Some parts of the script may not work correctly."
        fi
    else
        log "Homebrew is already installed."
    fi
fi

# Install Oh My Zsh
if ask_yes_no "Do you want to install Oh My Zsh?"; then
    install_oh_my_zsh
fi

# Casks with descriptions and URLs
casks=(
    "visual-studio-code"
    "discord"
    "logi-options-plus"
    "caffeine"
    "figma"
    "obsidian"
    "bitwarden"
    "firefox"
    "iterm2"
    "postman"
    "docker"
)

cask_descriptions=(
    "Visual Studio Code - Popular code editor (https://code.visualstudio.com/)"
    "Discord - Communication app for communities (https://discord.com/)"
    "Logi Options+ - Logitech device manager (https://www.logitech.com/en-us/software/logi-options-plus.html)"
    "Caffeine - Prevent your Mac from going to sleep (https://intelliscapesolutions.com/apps/caffeine)"
    "Figma - Collaborative interface design tool (https://www.figma.com/)"
    "Grammarly - Writing assistant (https://www.grammarly.com/)"
    "Obsidian - Knowledge base that works on local Markdown files (https://obsidian.md/)"
    "Bitwarden - Open source password manager (https://bitwarden.com/)"
    "Firefox - Web browser (https://www.mozilla.org/firefox/)"
    "iTerm2 - Terminal emulator for macOS (https://iterm2.com/)"
    "Postman - API development environment (https://www.postman.com/)"
    "Docker - Platform for building, sharing, and running containerized applications (https://www.docker.com/)"
)

log "Installing cask applications..."
for i in "${!casks[@]}"; do
    install_brew_package "cask" "${casks[$i]}" "${cask_descriptions[$i]}"
done

# Brew taps
taps=(
    "tarkah/tickrs"
    "hashicorp/tap"
    "dbcli/tap"
)

tap_descriptions=(
    "Tickrs - Real-time stock market ticker -- necessary for tickrs"
    "HashiCorp - HashiCorp formulae -- necessary for Terraform"
    "DBCLI - Database command-line tools -- necessary for pgcli"
)

# Install taps
log "Adding Homebrew taps..."
for i in "${!taps[@]}"; do
    tap="${taps[$i]}"
    description="${tap_descriptions[$i]}"
    if ask_yes_no "Do you want to add the tap $tap? ($description)"; then
        if ! $DRY_RUN; then
            brew tap "$tap" || log "Failed to tap $tap"
            progress_bar 2
        else
            log "[DRY RUN] Would tap $tap"
        fi
    else
        log "Skipping tap $tap"
    fi
done

# Formulas with descriptions and URLs
formulas=(
    "go"
    "zsh-syntax-highlighting"
    "fd"
    "fzf"
    "bat"
    "jq"
    "powerlevel10k"
    "pyenv"
    "pyenv-virtualenv"
    "tor"
    "docker-compose"
    "ctop"
    "jesseduffield/lazydocker/lazydocker"
    "grammarly-desktop"
    "awscli"
    "gh"
    "pgcli"
    "glow"
    "ripgrep"
    "bpytop"
    "lazygit"
    "spotify_player"
    "tmux"
    "tree"
    "nmap"
    "eza"
    "tldr"
    "neovim"
    "tickrs"
    "terraform"
)

formula_descriptions=(
    "Go - Open source programming language (https://golang.org/)"
    "Zsh Syntax Highlighting - Fish shell-like syntax highlighting for Zsh (https://github.com/zsh-users/zsh-syntax-highlighting)"
    "fd - Simple, fast and user-friendly alternative to find (https://github.com/sharkdp/fd)"
    "fzf - Command-line fuzzy finder (https://github.com/junegunn/fzf)"
    "bat - Cat clone with syntax highlighting and Git integration (https://github.com/sharkdp/bat)"
    "jq - Lightweight command-line JSON processor (https://stedolan.github.io/jq/)"
    "Powerlevel10k - Zsh theme (https://github.com/romkatv/powerlevel10k)"
    "pyenv - Python version management (https://github.com/pyenv/pyenv)"
    "pyenv-virtualenv - pyenv plugin for virtualenv (https://github.com/pyenv/pyenv-virtualenv)"
    "Tor - Anonymity network (https://www.torproject.org/)"
    "Docker Compose - Define and run multi-container Docker applications (https://docs.docker.com/compose/)"
    "ctop - Top-like interface for container metrics (https://github.com/bcicen/ctop)"
    "lazydocker - Docker management terminal UI (https://github.com/jesseduffield/lazydocker)"
    "AWS CLI - Command-line interface for AWS (https://aws.amazon.com/cli/)"
    "GitHub CLI - GitHub's official command line tool (https://cli.github.com/)"
    "pgcli - PostgreSQL CLI with autocompletion and syntax highlighting (https://www.pgcli.com/)"
    "Glow - Markdown reader for the terminal (https://github.com/charmbracelet/glow)"
    "ripgrep - Fast search tool (https://github.com/BurntSushi/ripgrep)"
    "bpytop - Resource monitor (https://github.com/aristocratos/bpytop)"
    "lazygit - Simple terminal UI for git commands (https://github.com/jesseduffield/lazygit)"
    "spotify_player - Command-line Spotify player (https://github.com/aome510/spotify-player)"
    "tmux - Terminal multiplexer (https://github.com/tmux/tmux)"
    "tree - Directory listing as a tree (http://mama.indstate.edu/users/ice/tree/)"
    "Nmap - Network discovery and security auditing tool (https://nmap.org/)"
    "eza - Modern replacement for ls (https://github.com/eza-community/eza)"
    "tldr - Simplified man pages (https://tldr.sh/)"
    "Neovim - Hyperextensible Vim-based text editor (https://neovim.io/)"
    "tickrs - Real-time stock market ticker (https://github.com/tarkah/tickrs)"
    "Terraform - Infrastructure as Code tool (https://www.terraform.io/)"
)

log "Installing formula applications..."
for i in "${!formulas[@]}"; do
    install_brew_package "formula" "${formulas[$i]}" "${formula_descriptions[$i]}"
done

# Oh My Zsh plugin installations
log "Installing Oh My Zsh plugins..."
if ask_yes_no "Do you want to install Oh My Zsh plugins?"; then
    if ! $DRY_RUN; then
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || log "Failed to install zsh-autosuggestions"
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting || log "Failed to install zsh-syntax-highlighting"
        git clone https://github.com/tom-doerr/zsh_codex.git ~/.oh-my-zsh/custom/plugins/zsh_codex || log "Failed to install zsh_codex"
        progress_bar 5
    else
        log "Would install Oh My Zsh plugins"
    fi
fi

# Configuration commands
log "Configuring shell..."
if ask_yes_no "Do you want to update your .zshrc file?"; then
    if ! $DRY_RUN; then
        {
            # p10k config
            echo 'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then'
            echo '  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"'
            echo 'fi'
            echo "source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme"
            echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

            # fzf
            echo '[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh'

            # Path and Oh My Zsh configuration
            echo 'export ZSH="$HOME/.oh-my-zsh"'
            echo "zstyle ':omz:update' mode auto"
            echo 'COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"'
            echo 'plugins=(git aws dirhistory docker docker-compose dotenv fzf golang nvm pep8 pip pylint zsh_codex zsh-autosuggestions zsh-syntax-highlighting)'
            echo 'source $ZSH/oh-my-zsh.sh'
            echo 'export LANG=en_US.UTF-8'

            # Completion enhancements
            echo "zstyle ':completion:*' menu select"
            echo "zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'"

            # Pyenv
            echo 'export PYENV_ROOT="$HOME/.pyenv"'
            echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"'
            echo 'eval "$(pyenv init -)"'
            echo 'eval "$(pyenv virtualenv-init -)"'

            # Go
            echo 'export GOROOT="$(brew --prefix golang)/libexec"'
            echo 'export GOPATH="${HOME}/go"'
            echo 'export PATH="${PATH}:${GOROOT}/bin:${GOPATH}/bin"'

            # NVM
            echo 'export NVM_DIR="$HOME/.nvm"'
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'
            echo '[ -s "$NVM_DIR/zsh_completion" ] && \. "$NVM_DIR/zsh_completion"  # This loads nvm zsh_completion'

            # Aliases
            echo 'alias zshconfig="vim ~/.zshrc"'
            echo 'alias vim="nvim"'
            echo 'alias cat="bat"'
            echo 'alias lzg="lazygit"'
            echo 'alias lzd="lazydocker"'
            echo 'alias ll="eza -lah --git --icons --group-directories-first --time-style=long-iso"'
            echo 'alias spot="spotify_player"'

            # Other configurations
            echo 'bindkey "^X" create_completion # Create completion for zsh_codex'
            echo 'export EDITOR="nvim"'
        } >>${ZDOTDIR:-$HOME}/.zshrc
        >>${ZDOTDIR:-$HOME}/.zshrc
        progress_bar 5
    else
        log "Would update .zshrc file"
    fi
fi

# NVM installation
if ask_yes_no "Do you want to install NVM?"; then
    log "Installing NVM..."
    if ! $DRY_RUN; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash || {
            log "Failed to install NVM"
            exit 1
        }
        log "Installing latest Node version..."
        source "$HOME/.nvm/nvm.sh"
        nvm install node || log "Failed to install latest Node version"
        progress_bar 10
    else
        log "Would install NVM and latest Node version"
    fi
fi

# Python installation and configuration
if ask_yes_no "Do you want to install Python?"; then
    read -p "Enter the Python version you want to install (default: 3.12.5): " python_version
    python_version=${python_version:-3.12.5}
    log "Installing Python $python_version..."
    if ! $DRY_RUN; then
        pyenv install "$python_version" || log "Failed to install Python $python_version"
        pyenv global "$python_version" || log "Failed to set Python $python_version as global"
        progress_bar 15
    else
        log "Would install Python $python_version and set it as global"
    fi
fi

# Go configuration
if ask_yes_no "Do you want to configure Go?"; then
    log "Configuring Go..."
    if ! $DRY_RUN; then
        mkdir -p $HOME/go/{bin,src,pkg}
        progress_bar 3
    else
        log "Would create Go directories"
    fi
fi

# fzf configuration
if ask_yes_no "Do you want to configure fzf?"; then
    log "Configuring fzf..."
    if ! $DRY_RUN; then
        $(brew --prefix)/opt/fzf/install || log "Failed to configure fzf"
        progress_bar 5
    else
        log "Would configure fzf"
    fi
fi

# Additional configurations
log "Performing additional configurations..."
if ask_yes_no "Do you want to configure Powerlevel10k?"; then
    if ! $DRY_RUN; then
        code ~/.p10k.zsh || log "Failed to open p10k configuration"
    else
        log "Would open p10k configuration"
    fi
fi
if ask_yes_no "Do you want to install the OpenAI Python package?"; then
    if ! $DRY_RUN; then
        pip3 install openai || log "Failed to install OpenAI Python package"
    else
        log "Would install OpenAI Python package"
    fi
fi
if ask_yes_no "Do you want to set up the OpenAI API configuration?"; then
    if ! $DRY_RUN; then
        touch ~/.config/openaiapirc
        echo "[openai]
secret_key =" >>~/.config/openaiapirc
        code ~/.config/openaiapirc || log "Failed to open OpenAI API configuration"
        log "Please configure your OpenAI API key in the opened file."
    else
        log "Would set up OpenAI API configuration"
    fi
fi

# Docker Desktop installation
if ask_yes_no "Do you want to download Docker Desktop?"; then
    log "Downloading Docker Desktop..."
    if ! $DRY_RUN; then
        curl -L -o "$HOME/Downloads/Docker.dmg" "https://desktop.docker.com/mac/main/arm64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-mac-arm64" || log "Failed to download Docker Desktop"
        log "Please manually install Docker Desktop from the downloaded .dmg file in your Downloads folder."
        progress_bar 10
    else
        log "Would download Docker Desktop"
    fi
fi

if ask_yes_no "Do you want to generate documentation for installed commands?"; then
    if ! $DRY_RUN; then
        generate_command_docs
    else
        log "[DRY RUN] Would generate command documentation"
    fi
fi

# Cleanup
if ask_yes_no "Do you want to clean up Homebrew cache?"; then
    if ! $DRY_RUN; then
        brew cleanup || log "Failed to clean up Homebrew cache"
        progress_bar 5
    else
        log "Would clean up Homebrew cache"
    fi
fi

# Final instructions
log "Installation process completed. Please follow these final steps:"
log "1. Restart your terminal or run 'source ~/.zshrc' to apply all changes."
log "2. Run 'p10k configure' to set up your Powerlevel10k prompt."
log "3. Install Docker Desktop from the .dmg file in your Downloads folder."
log "4. Configure Spotify by running 'spot' in the terminal."
log "5. Add your OpenAI API key to ~/.config/openaiapirc"

# End of script
log "Script execution completed. Check $LOG_FILE for details."
if $DRY_RUN; then
    log "This was a dry run. No changes were made to your system."
    log "To perform the actual installation, run the script without the --dry-run flag."
else
    log "Script execution completed. Check $LOG_FILE for details."
    echo "Installation log saved to: $LOG_FILE"
fi
