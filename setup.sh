#!/bin/bash
#===============================================================================
# Machine Setup Script
# Author: Sameed Khan
#
# Supports two modes:
#   ./setup.sh                  # remote server (headless)
#   ./setup.sh --mode desktop   # desktop workstation (GUI)
#
# Usage: git clone <repo> && cd <repo> && ./setup.sh [--mode desktop]
# Idempotent: safe to run multiple times.
# After setup completes, you can delete this directory.
#
# NOTE: vim is the default editor ($EDITOR). Neovim is installed as an
# optional editor but not set as default. Use 'nvim' to launch neovim.
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#===============================================================================
# Mode Selection
#===============================================================================

SETUP_MODE="remote"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            SETUP_MODE="$2"
            shift 2
            ;;
        --mode=*)
            SETUP_MODE="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--mode remote|desktop]"
            exit 1
            ;;
    esac
done

if [[ "$SETUP_MODE" != "remote" && "$SETUP_MODE" != "desktop" ]]; then
    echo "Invalid mode: $SETUP_MODE (must be 'remote' or 'desktop')"
    exit 1
fi

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

    # Detect display server (for desktop mode)
    HAS_DISPLAY="false"
    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        HAS_DISPLAY="true"
    fi

    # Detect distro
    DISTRO_ID=""
    if [ -f /etc/os-release ]; then
        DISTRO_ID=$(. /etc/os-release && echo "$ID")
    fi

    log "Platform: $ARCH, Package manager: $PKG_MANAGER, Mode: $SETUP_MODE"
    if [ "$SETUP_MODE" = "desktop" ]; then
        log "Distro: ${DISTRO_ID:-unknown}, Display server: $HAS_DISPLAY"
        if [ "$DISTRO_ID" != "ubuntu" ]; then
            warn "Desktop mode is tested on Ubuntu. Some installs (Ghostty .deb,"
            warn "Pop Shell, GNOME extensions) may need manual adjustments on $DISTRO_ID."
            read -rp "Continue anyway? [y/N]: " continue_anyway
            if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
                error "Aborted. Run with --mode remote for OS-agnostic setup."
                exit 1
            fi
        fi
    fi
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
ZELLIJ_VERSION="0.43.1"
ZOXIDE_VERSION="0.9.9"
NVM_VERSION="0.40.3"
NODE_VERSION="lts/*"
GHOSTTY_PPA_DEB_URL="https://github.com/maan2003/ghostty-ubuntu/releases/latest/download/ghostty_amd64.deb"

#===============================================================================
# System Package Installation
#===============================================================================

install_system_packages() {
    log "Installing system packages..."

    case "$PKG_MANAGER" in
        apt)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y \
                build-essential cmake curl wget git fd-find ripgrep jq tmux \
                libfuse2t64 unzip zip tar ninja-build autoconf automake libtool \
                python3 python3-venv tree pkg-config libssl-dev
            # Create fd symlink if needed (Ubuntu installs as fdfind)
            if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                mkdir -p "$HOME/.local/bin"
                ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
            fi
            ;;
        dnf)
            $SUDO dnf install -y \
                gcc gcc-c++ make cmake curl wget git fd-find ripgrep jq tmux \
                fuse-libs unzip tree pkg-config openssl-devel
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm \
                base-devel cmake curl wget git fd ripgrep jq tmux fuse2 unzip \
                tree pkg-config openssl
            ;;
        zypper)
            $SUDO zypper install -y \
                gcc gcc-c++ make cmake curl wget git fd ripgrep jq tmux \
                libfuse2 unzip tree pkg-config libopenssl-devel
            ;;
        brew)
            brew install cmake curl wget git fd ripgrep jq tmux unzip tree \
                pkg-config openssl
            ;;
    esac

    success "System packages installed"
}

install_desktop_system_packages() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    log "Installing desktop system packages..."

    case "$PKG_MANAGER" in
        apt)
            $SUDO apt-get install -y \
                wl-clipboard xclip gnome-tweaks gnome-shell-extension-prefs \
                protobuf-compiler libprotobuf-dev node-typescript
            ;;
        dnf)
            $SUDO dnf install -y \
                wl-clipboard xclip gnome-tweaks gnome-extensions-app \
                protobuf-compiler protobuf-devel
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm \
                wl-clipboard xclip gnome-tweaks gnome-shell-extensions \
                protobuf
            ;;
        zypper)
            $SUDO zypper install -y \
                wl-clipboard xclip gnome-tweaks gnome-shell-extensions \
                protobuf-devel
            ;;
        brew)
            warn "Desktop packages not applicable for macOS brew"
            ;;
    esac

    success "Desktop system packages installed"
}

#===============================================================================
# Vim Installation
#===============================================================================

install_vim() {
    # Desktop mode: install vim-gtk3 for +clipboard support
    # Remote mode: install plain vim
    if [ "$SETUP_MODE" = "desktop" ]; then
        if vim --version 2>/dev/null | grep -q '+clipboard'; then
            success "vim already installed with clipboard support"
            return
        fi
        log "Installing vim-gtk3 (with clipboard support)..."
        case "$PKG_MANAGER" in
            apt)    $SUDO apt-get install -y vim-gtk3 ;;
            dnf)    $SUDO dnf install -y vim-X11 ;;
            pacman) $SUDO pacman -S --needed --noconfirm gvim ;;
            zypper) $SUDO zypper install -y gvim ;;
            brew)   brew install vim ;;
        esac
        success "vim-gtk3 installed (with +clipboard)"
    else
        if command -v vim &>/dev/null; then
            success "vim already installed"
            return
        fi
        log "Installing vim..."
        case "$PKG_MANAGER" in
            apt)    $SUDO apt-get install -y vim ;;
            dnf)    $SUDO dnf install -y vim ;;
            pacman) $SUDO pacman -S --needed --noconfirm vim ;;
            zypper) $SUDO zypper install -y vim ;;
            brew)   brew install vim ;;
        esac
        success "vim installed"
    fi
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

install_btop() {
    if command -v btop &>/dev/null; then
        success "btop already installed: $(btop --version 2>&1 | head -1)"
        return
    fi
    log "Installing btop..."
    case "$PKG_MANAGER" in
        apt)    $SUDO apt-get install -y btop ;;
        dnf)    $SUDO dnf install -y btop ;;
        pacman) $SUDO pacman -S --needed --noconfirm btop ;;
        zypper) $SUDO zypper install -y btop ;;
        brew)   brew install btop ;;
    esac
    success "btop installed"
}

#===============================================================================
# Desktop Tool Installers (only in desktop mode)
#===============================================================================

install_zellij() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if command -v zellij &>/dev/null; then
        success "zellij already installed: $(zellij --version)"
        return
    fi
    log "Installing zellij..."
    local tmp
    tmp=$(mktemp -d)
    local zellij_arch="x86_64"
    [ "$ARCH" = "aarch64" ] && zellij_arch="aarch64"
    wget -q -O "$tmp/zellij.tar.gz" \
        "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-${zellij_arch}-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/zellij.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/bin"
    mv "$tmp/zellij" "$HOME/.local/bin/zellij"
    chmod +x "$HOME/.local/bin/zellij"
    rm -rf "$tmp"
    success "zellij installed: $(zellij --version)"
}

install_zoxide() {
    if command -v zoxide &>/dev/null; then
        success "zoxide already installed: $(zoxide --version)"
        return
    fi
    log "Installing zoxide..."
    local tmp
    tmp=$(mktemp -d)
    local zoxide_arch="x86_64"
    [ "$ARCH" = "aarch64" ] && zoxide_arch="aarch64"
    wget -q -O "$tmp/zoxide.tar.gz" \
        "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-${zoxide_arch}-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/zoxide.tar.gz" -C "$tmp"
    mkdir -p "$HOME/.local/bin"
    mv "$tmp/zoxide" "$HOME/.local/bin/zoxide"
    chmod +x "$HOME/.local/bin/zoxide"
    rm -rf "$tmp"
    success "zoxide installed: $(zoxide --version)"
}

install_ghostty() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if command -v ghostty &>/dev/null; then
        success "ghostty already installed: $(ghostty --version 2>&1 | head -1)"
        return
    fi
    if [ "$HAS_DISPLAY" != "true" ]; then
        warn "[SKIP] No display server — skipping Ghostty install"
        return
    fi
    log "Installing Ghostty..."
    case "$PKG_MANAGER" in
        apt)
            local tmp
            tmp=$(mktemp -d)
            local deb_arch="amd64"
            [ "$ARCH" = "aarch64" ] && deb_arch="arm64"
            # Try the community PPA .deb build
            wget -q -O "$tmp/ghostty.deb" \
                "https://github.com/maan2003/ghostty-ubuntu/releases/latest/download/ghostty_${deb_arch}.deb" || {
                warn "Failed to download Ghostty .deb — you may need to install manually"
                warn "See: https://ghostty.org/docs/install"
                rm -rf "$tmp"
                return
            }
            $SUDO dpkg -i "$tmp/ghostty.deb" || $SUDO apt-get install -f -y
            rm -rf "$tmp"
            ;;
        dnf)
            $SUDO dnf copr enable -y pgdev/ghostty
            $SUDO dnf install -y ghostty
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm ghostty
            ;;
        *)
            warn "Ghostty: no automated install for $PKG_MANAGER — install manually"
            warn "See: https://ghostty.org/docs/install"
            return
            ;;
    esac
    success "ghostty installed"
}

install_nerd_fonts() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    local font_dir="$HOME/.local/share/fonts"
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
        success "JetBrainsMono Nerd Font already installed"
        return
    fi
    log "Installing JetBrainsMono Nerd Font..."
    local tmp
    tmp=$(mktemp -d)
    wget -q -O "$tmp/JetBrainsMono.tar.xz" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"
    mkdir -p "$font_dir"
    tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir"
    fc-cache -f "$font_dir" 2>/dev/null || true
    rm -rf "$tmp"
    success "JetBrainsMono Nerd Font installed"
}

install_pop_shell() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if [ "$HAS_DISPLAY" != "true" ]; then
        warn "[SKIP] No display server — skipping Pop Shell install"
        return
    fi
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/pop-shell@system76.com"
    if [ -d "$ext_dir" ]; then
        success "Pop Shell already installed"
        return
    fi
    log "Installing Pop Shell GNOME extension (building from source)..."
    local tmp
    tmp=$(mktemp -d)
    git clone --depth 1 https://github.com/pop-os/shell.git "$tmp/pop-shell"
    cd "$tmp/pop-shell"
    make local-install 2>&1 || {
        warn "Pop Shell build failed — you may need to install manually"
        warn "See: https://github.com/pop-os/shell"
        cd "$SCRIPT_DIR"
        rm -rf "$tmp"
        return
    }
    cd "$SCRIPT_DIR"
    rm -rf "$tmp"

    # Enable the extension
    gnome-extensions enable pop-shell@system76.com 2>/dev/null || true

    # Apply default Pop Shell settings
    dconf write /org/gnome/shell/extensions/pop-shell/active-hint true
    dconf write /org/gnome/shell/extensions/pop-shell/tile-by-default true

    success "Pop Shell installed and enabled"
}

install_docker() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if command -v docker &>/dev/null; then
        success "docker already installed: $(docker --version)"
        return
    fi
    log "Installing Docker..."
    case "$PKG_MANAGER" in
        apt)
            # Install using Docker's official convenience script
            curl -fsSL https://get.docker.com | sh
            # Add current user to docker group (takes effect on next login)
            $SUDO usermod -aG docker "$USER" || true
            ;;
        dnf)
            $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            $SUDO systemctl enable --now docker
            $SUDO usermod -aG docker "$USER" || true
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm docker docker-compose
            $SUDO systemctl enable --now docker
            $SUDO usermod -aG docker "$USER" || true
            ;;
        zypper)
            $SUDO zypper install -y docker docker-compose
            $SUDO systemctl enable --now docker
            $SUDO usermod -aG docker "$USER" || true
            ;;
        brew)
            brew install --cask docker
            ;;
    esac
    success "Docker installed (log out and back in for group membership)"
}

set_default_terminal() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if [ "$HAS_DISPLAY" != "true" ]; then return; fi
    if ! command -v ghostty &>/dev/null; then return; fi

    log "Setting Ghostty as default terminal..."

    # Method 1: update-alternatives (Debian/Ubuntu)
    if command -v update-alternatives &>/dev/null; then
        local ghostty_path
        ghostty_path="$(command -v ghostty)"
        $SUDO update-alternatives --install /usr/bin/x-terminal-emulator \
            x-terminal-emulator "$ghostty_path" 50 2>/dev/null || true
        $SUDO update-alternatives --set x-terminal-emulator "$ghostty_path" 2>/dev/null || true
    fi

    # Method 2: gsettings for GNOME
    if command -v gsettings &>/dev/null; then
        # Check if ghostty has a .desktop file
        local desktop_file=""
        for f in /usr/share/applications/com.mitchellh.ghostty.desktop \
                 /usr/share/applications/ghostty.desktop \
                 "$HOME/.local/share/applications/ghostty.desktop"; do
            if [ -f "$f" ]; then
                desktop_file="$(basename "$f")"
                break
            fi
        done
        if [ -n "$desktop_file" ]; then
            # Set as preferred terminal in GNOME's xdg-terminal list
            if [ -f /etc/xdg-terminals.list ] || [ -f "$HOME/.config/xdg-terminals.list" ]; then
                if ! grep -q "$desktop_file" "$HOME/.config/xdg-terminals.list" 2>/dev/null; then
                    echo "$desktop_file" > "$HOME/.config/xdg-terminals.list"
                fi
            fi
        fi
    fi

    success "Ghostty set as default terminal"
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

install_jj() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if command -v jj &>/dev/null; then
        success "jj already installed: $(jj --version)"
        return
    fi
    log "Installing Jujutsu (jj) via cargo (this may take a few minutes)..."
    # Ensure cargo is available
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi
    cargo install --locked jj-cli
    success "jj installed: $(jj --version)"
}

install_nvm_and_node() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        success "nvm already installed"
    else
        log "Installing nvm..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
        success "nvm installed"
    fi

    # Source nvm for this session
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Node.js LTS via nvm (ignore system node which may lack npm)
    if nvm ls "$NODE_VERSION" &>/dev/null 2>&1 && command -v npm &>/dev/null; then
        success "Node.js already installed via nvm: $(node --version)"
    else
        log "Installing Node.js (LTS) via nvm..."
        nvm install "$NODE_VERSION"
        nvm alias default "$NODE_VERSION"
        nvm use default
        success "Node.js installed: $(node --version)"
    fi
}

install_pi_coding_agent() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    # Ensure nvm/node are available
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command -v node &>/dev/null; then
        warn "Node.js not available — skipping pi-coding-agent install"
        return
    fi

    if command -v pi &>/dev/null; then
        success "pi-coding-agent already installed"
    else
        log "Installing pi-coding-agent and extensions..."
        npm install -g @mariozechner/pi-coding-agent
        success "pi-coding-agent installed"
    fi

    # Install core extensions (idempotent — npm won't reinstall if present)
    log "Ensuring pi extensions are installed..."
    local extensions=(
        pi-subagents
        pi-web-access
        pi-exa-search
        pi-interactive-shell
        pi-mcp-adapter
        pi-rewind
        pi-agent-extensions
        @yofriadi/pi-lsp
        @zhafron/pi-mcp-tools
        @javimolina/pi-palette
    )
    for ext in "${extensions[@]}"; do
        if npm list -g "$ext" &>/dev/null; then
            success "  $ext already installed"
        else
            npm install -g "$ext" && success "  $ext installed" || warn "  $ext failed to install"
        fi
    done
}

#===============================================================================
# Enterprise Certificates (optional)
#===============================================================================

install_enterprise_certs() {
    # Check if already installed
    if [ -f /usr/local/share/ca-certificates/forcepoint-ca.crt ] && \
       [ -f /usr/local/share/ca-certificates/forcepoint.crt ]; then
        success "Forcepoint enterprise certificates already installed"
        return
    fi

    log "Enterprise SSL inspection detected (Forcepoint)."
    read -rp "Install Forcepoint enterprise SSL certificates? [y/N]: " install_certs
    if [[ ! "$install_certs" =~ ^[Yy]$ ]]; then
        warn "Skipping enterprise certificate installation"
        return
    fi

    log "Installing Forcepoint enterprise certificates..."

    # Copy certs to system CA directory
    $SUDO cp "$SCRIPT_DIR/certs/forcepoint-ca.crt" /usr/local/share/ca-certificates/forcepoint-ca.crt
    $SUDO cp "$SCRIPT_DIR/certs/forcepoint.crt" /usr/local/share/ca-certificates/forcepoint.crt

    # Rebuild system CA bundle (creates symlinks in /etc/ssl/certs/ and
    # appends to /etc/ssl/certs/ca-certificates.crt)
    $SUDO update-ca-certificates

    success "Forcepoint certificates installed to system CA store"
    ENTERPRISE_CERTS_INSTALLED=true
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

deploy_desktop_configs() {
    if [ "$SETUP_MODE" != "desktop" ]; then return; fi
    log "Deploying desktop configurations..."

    # Ghostty config
    if command -v ghostty &>/dev/null || [ "$HAS_DISPLAY" = "true" ]; then
        mkdir -p "$HOME/.config/ghostty"
        if [ -f "$HOME/.config/ghostty/config" ]; then
            warn "Existing Ghostty config found"
            read -rp "Overwrite? [y/N]: " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                cp "$SCRIPT_DIR/config/ghostty.config" "$HOME/.config/ghostty/config"
                success "Ghostty config deployed"
            else
                warn "Skipping Ghostty config deployment"
            fi
        else
            cp "$SCRIPT_DIR/config/ghostty.config" "$HOME/.config/ghostty/config"
            success "Ghostty config deployed"
        fi
    fi

    # Zellij config
    if command -v zellij &>/dev/null; then
        mkdir -p "$HOME/.config/zellij"
        if [ -f "$HOME/.config/zellij/config.kdl" ]; then
            warn "Existing Zellij config found"
            read -rp "Overwrite? [y/N]: " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                cp "$SCRIPT_DIR/config/zellij.kdl" "$HOME/.config/zellij/config.kdl"
                success "Zellij config deployed"
            else
                warn "Skipping Zellij config deployment"
            fi
        else
            cp "$SCRIPT_DIR/config/zellij.kdl" "$HOME/.config/zellij/config.kdl"
            success "Zellij config deployed"
        fi
    fi

    # Jujutsu config
    if command -v jj &>/dev/null; then
        mkdir -p "$HOME/.config/jj"
        if [ -f "$HOME/.config/jj/config.toml" ]; then
            warn "Existing jj config found"
            read -rp "Overwrite? [y/N]: " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                cp "$SCRIPT_DIR/config/jj.toml" "$HOME/.config/jj/config.toml"
                success "jj config deployed"
            else
                warn "Skipping jj config deployment"
            fi
        else
            cp "$SCRIPT_DIR/config/jj.toml" "$HOME/.config/jj/config.toml"
            success "jj config deployed"
        fi
    fi

    # Pop Shell config
    if [ -d "$HOME/.local/share/gnome-shell/extensions/pop-shell@system76.com" ]; then
        mkdir -p "$HOME/.config/pop-shell"
        cp "$SCRIPT_DIR/config/pop-shell.json" "$HOME/.config/pop-shell/config.json"
        success "Pop Shell config deployed"
    fi

    success "Desktop configurations deployed"
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
    echo ""
    if [ "$SETUP_MODE" = "desktop" ]; then
        log "=== Desktop Workstation Setup ==="
    else
        log "=== Remote Server Setup ==="
    fi
    log "Running as: $(whoami)"

    detect_platform

    mkdir -p "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    # Phase 1: System packages (may require sudo)
    install_system_packages
    install_desktop_system_packages
    install_vim

    # Phase 2: Binary tools (common)
    install_just
    install_bat
    install_delta
    install_starship
    install_neovim
    install_et
    install_btop
    install_zoxide

    # Phase 3: Desktop-only binary tools
    install_zellij
    install_ghostty
    install_nerd_fonts

    # Phase 4: User-space tools (common)
    install_uv
    install_fzf
    install_rust_and_yazi

    # Phase 5: Desktop-only user-space tools
    install_jj
    install_nvm_and_node
    install_pi_coding_agent
    install_docker

    # Phase 6: GNOME extensions (desktop)
    install_pop_shell

    # Phase 7: Enterprise certificates (optional)
    install_enterprise_certs

    # Phase 8: Configuration
    configure_git
    deploy_configs
    deploy_desktop_configs

    # Phase 10: Default terminal
    set_default_terminal

    # Phase 11: Neovim plugin setup
    setup_neovim_plugins

    # Phase 12: Verification
    log ""
    log "Verifying installations..."
    local common_tools="vim nvim just bat delta starship et jq tmux uv fzf yazi btop zoxide"
    local desktop_tools="zellij ghostty jj node docker"

    for cmd in $common_tools; do
        if command -v "$cmd" &>/dev/null; then
            success "$cmd: $(command -v "$cmd")"
        else
            warn "$cmd not found in PATH"
        fi
    done

    if [ "$SETUP_MODE" = "desktop" ]; then
        for cmd in $desktop_tools; do
            if command -v "$cmd" &>/dev/null; then
                success "$cmd: $(command -v "$cmd")"
            else
                warn "$cmd not found in PATH"
            fi
        done

        # Check GNOME extensions
        if gnome-extensions list 2>/dev/null | grep -q pop-shell; then
            success "Pop Shell GNOME extension: installed"
        else
            warn "Pop Shell GNOME extension: not detected"
        fi

        # Check Nerd Font
        if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
            success "JetBrainsMono Nerd Font: installed"
        else
            warn "JetBrainsMono Nerd Font: not detected"
        fi
    fi

    log ""
    log "=== Setup Complete ==="
    log "Mode: $SETUP_MODE"
    log "Restart your shell or run: source ~/.bashrc"
    log "Default editor: vim (\$EDITOR=vim)"
    log "Neovim is available at: $(command -v nvim 2>/dev/null || echo 'not installed')"
    if [ "$SETUP_MODE" = "desktop" ]; then
        log "Terminal: Ghostty + Zellij"
        log "Tiling WM: Pop Shell (GNOME extension)"
        log "Docker: log out and back in for group membership to take effect"
    fi

    if [ "${ENTERPRISE_CERTS_INSTALLED:-}" = "true" ]; then
        log ""
        log "╔══════════════════════════════════════════════════════════════╗"
        log "║  FIREFOX CERTIFICATE CONFIGURATION (manual step required)   ║"
        log "╠══════════════════════════════════════════════════════════════╣"
        log "║                                                            ║"
        log "║  Firefox does not automatically use system CA certificates. ║"
        log "║  To fix SSL errors on enterprise-inspected sites:           ║"
        log "║                                                            ║"
        log "║  1. Open Firefox                                           ║"
        log "║  2. Navigate to:  about:config                             ║"
        log "║  3. Accept the risk warning                                ║"
        log "║  4. Search for:   security.enterprise_roots.enabled        ║"
        log "║  5. Set it to:    true  (double-click to toggle)           ║"
        log "║  6. Restart Firefox                                        ║"
        log "║                                                            ║"
        log "║  This tells Firefox to import CAs from the system store,   ║"
        log "║  including the Forcepoint certificates just installed.     ║"
        log "║                                                            ║"
        log "╚══════════════════════════════════════════════════════════════╝"
    fi

    log ""
    log "You can now delete this directory: rm -rf $SCRIPT_DIR"
}

main "$@"
