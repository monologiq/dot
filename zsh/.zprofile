# CORE

if [ -e "/opt/homebrew/bin/brew" ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
	export HOMEBREW_BUNDLE_FILE="$XDG_CONFIG_HOME/homebrew/Brewfile"
fi

if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
	. '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# DEVELOPMENT

export BINPATH="$HOME/.local/bin"
PATH+=":$BINPATH"

export GOPATH="$XDG_CACHE_HOME/go"
PATH+=":$GOPATH/bin"

export N_PREFIX="$XDG_CACHE_HOME/n"
PATH+=":$N_PREFIX/bin"

if [ -r "$ZDOTDIR/.zlocal" ]; then
	source "$ZDOTDIR/.zlocal"
fi
