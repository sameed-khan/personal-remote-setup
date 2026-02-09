#!/bin/bash
#===============================================================================
# Remote Server Setup Script
# Author: Sameed Khan
#
# Usage: git clone <repo> && cd <repo> && ./setup.sh
# Idempotent: safe to run multiple times.
# After setup completes, you can delete this directory.
#
# NOTE: vim is the default editor ($EDITOR). Neovim is installed as an
# optional editor but not set as default. Use 'nvim' to launch neovim.
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#===============================================================================
# Logging
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

#===============================================================================
# Platform Detection
#===============================================================================

detect_platform() {
    ARCH=$(uname -m) # x86_64 or aarch64

    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MANAGER="zypper"
    elif command -v brew &>/dev/null; then
        PKG_MANAGER="brew"
    else
        error "No supported package manager found"
        exit 1
    fi

    log "Platform: $ARCH, Package manager: $PKG_MANAGER"
}

# Detect if we need sudo for system packages
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        warn "Not root and sudo not available. System package installation may fail."
    fi
fi

#===============================================================================
# Tool Versions (update these as needed)
#===============================================================================

BAT_VERSION="0.26.1"
DELTA_VERSION="0.18.2"

#===============================================================================
# System Package Installation
#===============================================================================

install_system_packages() {
    log "Installing system packages..."

    case "$PKG_MANAGER" in
        apt)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y \
                build-essential cmake curl wget git fd-find ripgrep jq tmux libfuse2 unzip
            # Create fd symlink if needed (Ubuntu installs as fdfind)
            if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                mkdir -p "$HOME/.local/bin"
                ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
            fi
            ;;
        dnf)
            $SUDO dnf install -y \
                gcc gcc-c++ make cmake curl wget git fd-find ripgrep jq tmux fuse-libs unzip
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm \
                base-devel cmake curl wget git fd ripgrep jq tmux fuse2 unzip
            ;;
        zypper)
            $SUDO zypper install -y \
                gcc gcc-c++ make cmake curl wget git fd ripgrep jq tmux libfuse2 unzip
            ;;
        brew)
            brew install cmake curl wget git fd ripgrep jq tmux unzip
            ;;
    esac

    success "System packages installed"
}

#===============================================================================
# Binary Tool Installers (idempotent)
#===============================================================================

install_just() {
    if command -v just &>/dev/null; then
        success "just already installed: $(just --version)"
        return
    fi
    log "Installing just..."
    mkdir -p "$HOME/.local/bin"
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
    success "just installed"
}

install_bat() {
    if command -v bat &>/dev/null; then
        success "bat already installed: $(bat --version | head -1)"
        return
    fi
    log "Installing bat..."
    case "$PKG_MANAGER" in
        apt)
            local tmp
            tmp=$(mktemp -d)
            local deb_arch="amd64"
            [ "$ARCH" = "aarch64" ] && deb_arch="arm64"
            wget -q -O "$tmp/bat.deb" "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_${deb_arch}.deb"
            $SUDO dpkg -i "$tmp/bat.deb"
            rm -rf "$tmp"
            ;;
        dnf)    $SUDO dnf install -y bat ;;
        pacman) $SUDO pacman -S --needed --noconfirm bat ;;
        zypper) $SUDO zypper install -y bat ;;
        brew)   brew install bat ;;
    esac
    success "bat installed"
}

install_delta() {
    if command -v delta &>/dev/null; then
        success "delta already installed: $(delta --version | head -1)"
        return
    fi
    log "Installing delta..."
    case "$PKG_MANAGER" in
        apt)
            local tmp
            tmp=$(mktemp -d)
            local deb_arch="amd64"
            [ "$ARCH" = "aarch64" ] && deb_arch="arm64"
            wget -q -O "$tmp/delta.deb" "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${deb_arch}.deb"
            $SUDO dpkg -i "$tmp/delta.deb"
            rm -rf "$tmp"
            ;;
        dnf)    $SUDO dnf install -y git-delta ;;
        pacman) $SUDO pacman -S --needed --noconfirm git-delta ;;
        zypper) $SUDO zypper install -y git-delta ;;
        brew)   brew install git-delta ;;
    esac
    success "delta installed"
}

install_starship() {
    if command -v starship &>/dev/null; then
        success "starship already installed: $(starship --version)"
        return
    fi
    log "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    success "starship installed"
}

install_neovim() {
    if command -v nvim &>/dev/null; then
        success "neovim already installed: $(nvim --version | head -1)"
        return
    fi
    log "Installing neovim..."
    local tmp
    tmp=$(mktemp -d)
    local appimage_name="nvim-linux-x86_64.appimage"
    [ "$ARCH" = "aarch64" ] && appimage_name="nvim-linux-aarch64.appimage"

    wget -q -O "$tmp/nvim.appimage" "https://github.com/neovim/neovim/releases/latest/download/${appimage_name}"
    chmod +x "$tmp/nvim.appimage"

    # Try running directly (requires FUSE), otherwise extract
    if "$tmp/nvim.appimage" --version &>/dev/null; then
        mkdir -p "$HOME/.local/bin"
        mv "$tmp/nvim.appimage" "$HOME/.local/bin/nvim"
    else
        log "FUSE not available, extracting AppImage..."
        cd "$tmp"
        ./nvim.appimage --appimage-extract
        $SUDO rm -rf /opt/nvim
        $SUDO mv squashfs-root /opt/nvim
        $SUDO ln -sf /opt/nvim/usr/bin/nvim /usr/local/bin/nvim
        cd "$SCRIPT_DIR"
    fi
    rm -rf "$tmp"
    success "neovim installed: $(nvim --version | head -1)"
}

install_et() {
    if command -v et &>/dev/null; then
        success "Eternal Terminal already installed"
        return
    fi
    log "Installing Eternal Terminal from source..."
    local tmp
    tmp=$(mktemp -d)
    git clone --recurse-submodules --depth 1 https://github.com/MisterTea/EternalTerminal.git "$tmp/EternalTerminal"
    mkdir -p "$tmp/EternalTerminal/build"
    cd "$tmp/EternalTerminal/build"
    cmake ../
    make
    $SUDO make install
    cd "$SCRIPT_DIR"
    rm -rf "$tmp"
    success "Eternal Terminal installed"
}

#===============================================================================
# User-Space Installers (no sudo needed)
#===============================================================================

install_uv() {
    if command -v uv &>/dev/null; then
        success "uv already installed: $(uv --version)"
        return
    fi
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    success "uv installed"
}

install_fzf() {
    if command -v fzf &>/dev/null; then
        success "fzf already installed: $(fzf --version | head -1)"
        return
    fi
    log "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all --no-update-rc
    success "fzf installed"
}

install_rust_and_yazi() {
    # Install rustc/cargo if not present
    if ! command -v cargo &>/dev/null; then
        log "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
        rustup update
        success "Rust installed: $(rustc --version)"
    else
        success "Rust already installed: $(rustc --version)"
    fi

    # Install yazi via yazi-build (installs both yazi-fm and yazi-cli)
    if command -v yazi &>/dev/null; then
        success "yazi already installed: $(yazi --version | head -1)"
        return
    fi
    log "Installing yazi (this may take a few minutes)..."
    cargo install --force yazi-build
    success "yazi installed"
}

#===============================================================================
# Git Configuration
#===============================================================================

configure_git() {
    log "Configuring git..."

    # Only set user info if not already configured
    if ! git config --global user.name &>/dev/null; then
        read -rp "Git user.name (leave empty to skip): " git_name
        [ -n "$git_name" ] && git config --global user.name "$git_name"
    fi

    if ! git config --global user.email &>/dev/null; then
        read -rp "Git user.email (leave empty to skip): " git_email
        [ -n "$git_email" ] && git config --global user.email "$git_email"
    fi

    # Set tool preferences (idempotent)
    # Note: Using vim as default editor, nvim is available but not the default
    git config --global core.editor vim
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global delta.line-numbers true
    git config --global merge.conflictstyle diff3
    git config --global diff.colorMoved default

    success "Git configured"
}

#===============================================================================
# Deploy Configurations
#===============================================================================

deploy_configs() {
    log "Deploying configurations..."

    mkdir -p "$HOME/.config" "$HOME/.local/bin"

    # Vim config
    if [ -f "$HOME/.vimrc" ]; then
        warn "Existing vim config found at ~/.vimrc"
        read -rp "Overwrite? [y/N]: " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            cp "$SCRIPT_DIR/config/vimrc" "$HOME/.vimrc"
            success "Vim config deployed to ~/.vimrc"
        else
            warn "Skipping vim config deployment"
        fi
    else
        cp "$SCRIPT_DIR/config/vimrc" "$HOME/.vimrc"
        success "Vim config deployed to ~/.vimrc"
    fi

    # Neovim config (optional, not the default editor)
    if [ -d "$HOME/.config/nvim" ]; then
        warn "Existing neovim config found at ~/.config/nvim"
        read -rp "Overwrite? [y/N]: " overwrite
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.config/nvim"
        else
            warn "Skipping neovim config deployment"
            SKIP_NVIM=true
        fi
    fi

    if [ "${SKIP_NVIM:-}" != "true" ]; then
        cp -r "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
        success "Neovim config deployed to ~/.config/nvim"
    fi

    # Starship config
    cp "$SCRIPT_DIR/config/starship.toml" "$HOME/.config/starship.toml"
    success "Starship config deployed"

    # Tmux config
    cp "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf"
    success "Tmux config deployed"

    # Bashrc custom
    cp "$SCRIPT_DIR/config/bashrc_custom" "$HOME/.bashrc_custom"
    success "Bashrc custom deployed"

    # Source custom bashrc from main bashrc (idempotent)
    if ! grep -q "bashrc_custom" "$HOME/.bashrc" 2>/dev/null; then
        echo '' >> "$HOME/.bashrc"
        echo '# Load custom configuration' >> "$HOME/.bashrc"
        echo '[ -f ~/.bashrc_custom ] && source ~/.bashrc_custom' >> "$HOME/.bashrc"
    fi
    success "Bashrc source line added"
}

#===============================================================================
# Post-Install: Neovim Plugins and LSP Servers
#===============================================================================

setup_neovim_plugins() {
    if [ "${SKIP_NVIM:-}" = "true" ]; then
        return
    fi

    log "Syncing neovim plugins (this may take a minute)..."
    nvim --headless "+Lazy! sync" +qa 2>&1 || warn "Lazy sync had issues (may be fine on first run)"

    log "Installing LSP servers via Mason..."
    nvim --headless "+MasonInstall ty ruff" +qa 2>&1 || warn "Mason install had issues"

    success "Neovim plugins and LSP servers installed"
}

#===============================================================================
# Main
#===============================================================================

main() {
    log "=== Remote Server Setup ==="
    log "Running as: $(whoami)"

    detect_platform

    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Phase 1: System packages (may require sudo)
    install_system_packages

    # Phase 2: Binary tools
    install_just
    install_bat
    install_delta
    install_starship
    install_neovim
    install_et

    # Phase 3: User-space tools
    install_uv
    install_fzf
    install_rust_and_yazi

    # Phase 4: Configuration
    configure_git
    deploy_configs

    # Phase 5: Neovim plugin setup
    setup_neovim_plugins

    # Phase 6: Verification
    log ""
    log "Verifying installations..."
    for cmd in vim nvim just bat delta starship et jq tmux uv fzf yazi; do
        if command -v "$cmd" &>/dev/null; then
            success "$cmd: $(command -v "$cmd")"
        else
            warn "$cmd not found in PATH"
        fi
    done

    log ""
    log "=== Setup Complete ==="
    log "Restart your shell or run: source ~/.bashrc"
    log "Default editor: vim (\$EDITOR=vim)"
    log "Neovim is available at: $(command -v nvim 2>/dev/null || echo 'not installed')"
    log "You can now delete this directory: rm -rf $SCRIPT_DIR"
}

main "$@"
