#!/usr/bin/env bash

set -e

DOT="$HOME/.dot"
KEY_FILE=""

readonly DOT_REMOTE_HOST="github.com"
readonly DOT_REMOTE_USER="monologiq"
readonly DOT_REMOTE_NAME="dotfiles"
readonly DOT_REMOTE_BRANCH="master"
readonly DOT_REMOTE_HTTP_URL="https://${DOT_REMOTE_HOST}/${DOT_REMOTE_USER}/${DOT_REMOTE_NAME}"
readonly DOT_REMOTE_SSH_URL="git@${DOT_REMOTE_HOST}:${DOT_REMOTE_USER}/${DOT_REMOTE_NAME}"
readonly TARBALL_URL="${DOT_REMOTE_HTTP_URL}/archive/refs/heads/${DOT_REMOTE_BRANCH}.tar.gz"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_ssh_connection() {
    if ssh -T -o ConnectTimeout=10 "git@$DOT_REMOTE_HOST" 2>&1 | grep -q "successfully authenticated"; then
        return 0
    else
        return 1
    fi
}

is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

abort() {
    echo "Error: $1" >&2
    exit 1
}

confirm_installation() {
    echo
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
}

download_dotfiles() {
    local temp_file="/tmp/${DOT_REMOTE_NAME}.tar.gz"

    echo "Downloading dotfiles..."

    if ! curl -fsSL -o "$temp_file" "$TARBALL_URL"; then
        abort "Failed to download dotfiles archive"
    fi

    [[ -d "$DOT" ]] && rm -rf "$DOT"
    mkdir -p "$DOT"

    if ! tar -xzf "$temp_file" -C "$DOT" --strip-components=1; then
        abort "Failed to extract dotfiles archive"
    fi

    rm "$temp_file"
}

generate_zshenv() {
    local zshenv_path="$HOME/.zshenv"

    if [[ -f "$zshenv_path" ]]; then
        echo "Warning: ${zshenv_path} already exists, overwriting..."
    fi

    cat >"$zshenv_path" <<EOF
# Generated on: $(date)
export DOT="$DOT"
export DOT_REMOTE_HOST="$DOT_REMOTE_HOST"
export DOT_REMOTE_USER="$DOT_REMOTE_USER"
export DOT_REMOTE_NAME="$DOT_REMOTE_NAME"
export DOT_REMOTE_BRANCH="$DOT_REMOTE_BRANCH"
export DOT_REMOTE_HTTP_URL="$DOT_REMOTE_HTTP_URL"
export DOT_REMOTE_SSH_URL="$DOT_REMOTE_SSH_URL"

export ZDOTDIR="\$HOME/.config/zsh"

if [ -f "\$ZDOTDIR/.zshenv" ]; then
    source "\$ZDOTDIR/.zshenv"
else
    PATH+="\$DOT/bin"
    source "\$DOT/zsh/.zshenv"
    source "\$DOT/zsh/.zprofile"
    source "\$DOT/zsh/.zshrc"

    [ -n "\$XDG_CACHE_HOME" ] && mkdir -p "\$XDG_CACHE_HOME"
    [ -n "\$XDG_CONFIG_HOME" ] && mkdir -p "\$XDG_CONFIG_HOME"
    [ -n "\$XDG_DATA_HOME" ] && mkdir -p "\$XDG_DATA_HOME"
    [ -n "\$XDG_STATE_HOME" ] && mkdir -p "\$XDG_STATE_HOME"
    [ -n "\$ZDOTDIR" ] && mkdir -p "\$ZDOTDIR"
fi
EOF

    chmod 644 "$zshenv_path"
}

setup_xdg_directories() {
    if ! is_macos; then
        export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/Library/Caches}"
    else
        export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    fi
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
    export DOT_BINPATH="${DOT_BINPATH:-$HOME/.local/bin}"

    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$ZDOTDIR" "$DOT_BINPATH"
}

create_symlink() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ ! -d "$DOT/$source_dir" ]]; then
        return 0
    fi

    mkdir -p "$target_dir"

    if ! stow --no-folding -v -R -S "$source_dir" -d "$DOT" -t "$target_dir" >/dev/null 2>&1; then
        echo "Warning: Failed to link $source_dir"
    fi
}

install_command_line_tools() {
    if ! is_macos; then
        return 0
    fi

    if xcode-select -p >/dev/null 2>&1; then
        return 0
    fi

    echo "Installing Xcode Command Line Tools..."
    xcode-select --install

    until xcode-select -p >/dev/null 2>&1; do
        sleep 5
    done
}

install_homebrew() {
    if ! is_macos; then
        return 0
    fi

    if [[ -e "/opt/homebrew/bin/brew" ]] || command_exists brew; then
        return 0
    fi

    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -e "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
}

install_packages() {
    if is_macos && command_exists brew; then
        brew install stow git age 2>/dev/null || true
    fi
}

init_git_repo() {
    cd "$DOT"
    [[ -d ".git" ]] && rm -rf ".git"
    git init
    git remote add origin "$DOT_REMOTE_SSH_URL"
    git fetch origin "$DOT_REMOTE_BRANCH"
    git reset --hard "origin/$DOT_REMOTE_BRANCH"
}

decrypt_age_files() {
    echo "Decrypting age files..."

    if [[ ! -f "$KEY_FILE" ]]; then
        abort "Age key file not found: $KEY_FILE"
    fi

    if ! command_exists age; then
        abort "Age is required for decryption but not available"
    fi

    local encrypted_files
    encrypted_files=$(find "$DOT" -name "*.age" -type f 2>/dev/null || true)

    if [[ -n "$encrypted_files" ]]; then
        while IFS= read -r age_file; do
            if [[ -n "$age_file" ]]; then
                local decrypted_file="${age_file%.age}"
                echo "Decrypting $(basename "$age_file")..."
                if ! age -d -i "$KEY_FILE" "$age_file" >"$decrypted_file" 2>/dev/null; then
                    abort "Failed to decrypt $(basename "$age_file")"
                fi
            fi
        done <<<"$encrypted_files"
    fi
}

load_ssh_keys() {
    if [[ ! -d "$HOME/.ssh" ]]; then
        return 0
    fi

    if [[ -z "$SSH_AUTH_SOCK" ]]; then
        eval "$(ssh-agent -s)"
    fi

    for key in "$HOME/.ssh"/id_* "$HOME/.ssh"/*_rsa "$HOME/.ssh"/*_ed25519 "$HOME/.ssh"/*_ecdsa; do
        if [[ -f "$key" && ! "$key" == *.pub ]]; then
            echo "Found SSH key: $(basename "$key")"

            if is_macos; then
                read -p "Add $(basename "$key") to keychain? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    ssh-add --apple-use-keychain "$key" 2>/dev/null || abort "Failed to add $(basename "$key") to keychain"
                else
                    ssh-add "$key" 2>/dev/null || abort "Failed to add $(basename "$key")"
                fi
            else
                read -p "Add $(basename "$key")? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    ssh-add "$key" 2>/dev/null || abort "Failed to add $(basename "$key")"
                fi
            fi
        fi
    done

    if ! ssh-add -l >/dev/null 2>&1; then
        echo "No keys loaded, attempting to load default keys..."
        ssh-add 2>/dev/null || abort "No default keys found"
    fi
}

setup_symlinks() {
    echo "Setting up symlinks..."
    create_symlink "bin" "$DOT_BINPATH"
    create_symlink "lib" "$DOT_BINPATH/lib"
    create_symlink "git" "$XDG_CONFIG_HOME/git"
    create_symlink "ghostty" "$XDG_CONFIG_HOME/ghostty"
    create_symlink "homebrew" "$XDG_CONFIG_HOME/homebrew"
    create_symlink "zsh" "$ZDOTDIR"
    create_symlink "ssh" "$HOME/.ssh"
}

main() {
    echo "Starting dotfiles installation..."
    echo "Repository: $DOT_REMOTE_HTTP_URL"
    echo "Target directory: $DOT"

    confirm_installation

    if [[ -z "${HOME:-}" ]]; then
        abort "HOME environment variable is not set"
    fi

    if [[ ! -w "$HOME" ]]; then
        abort "HOME directory is not writable"
    fi

    setup_xdg_directories
    install_command_line_tools
    install_homebrew
    install_packages

    if ! command_exists stow; then
        abort "GNU Stow is required but not available"
    fi

    if ! command_exists git; then
        abort "Git is required but not available"
    fi

    download_dotfiles

    if [[ -n "$KEY_FILE" ]]; then
        decrypt_age_files

        load_ssh_keys

        echo "Testing SSH connection..."
        if ! check_ssh_connection; then
            abort "SSH connection test failed"
        fi

        setup_symlinks

        init_git_repo

        generate_zshenv

        echo
        echo "Dotfiles installation completed successfully!"
        echo "Restart your shell or run: source ~/.zshenv"
        echo "Repository location: $DOT"
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
    --help | -h)
        echo "Usage: $0 [--dir DIRECTORY] [--key KEY_FILE]"
        echo "Install dotfiles configuration on a clean system"
        echo
        echo "Options:"
        echo "  --dir DIRECTORY    Install dotfiles to custom directory (default: ~/.dot)"
        echo "  --key KEY_FILE     Age private key file for decrypting files"
        echo "  --help, -h         Show this help message"
        echo
        echo "Examples:"
        echo "  $0 --key ~/.age/dot"
        echo "  $0 --dir /tmp/test --key ~/.age/dot"
        echo
        exit 0
        ;;
    --dir)
        if [[ -z "${2:-}" ]]; then
            abort "Error: --dir requires a directory argument"
        fi
        DOT="$2"
        shift 2
        ;;
    --key)
        if [[ -z "${2:-}" ]]; then
            abort "Error: --key requires a key file argument"
        fi
        KEY_FILE="$2"
        shift 2
        ;;
    "")
        break
        ;;
    *)
        abort "Unknown argument: $1. Use --help for usage information."
        ;;
    esac
done

main
