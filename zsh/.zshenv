#  Utilities
is_host() {
	local host="$(uname -s)"
	eval test $host = $1
	echo $?
}

export IS_MACOS="$(is_host Darwin)"
export IS_LINUX="$(is_host Linux)"

# XDG base directory specifications
# See: https://specifications.freedesktop.org/basedir-spec/latest/#variables

[ $IS_MACOS ] && export XDG_CACHE_HOME="$HOME/Library/Caches" || export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config" && mkdir -p $XDG_CONFIG_HOME &>/dev/null
export XDG_DATA_HOME="$HOME/.local/share" && mkdir -p $XDG_DATA_HOME &>/dev/null
export XDG_DATA_STATE="$HOME/.local/state" && mkdir -p $XDG_DATA_STATE &>/dev/null

# ZSH Options
# See `man zshoptions`

setopt AUTO_CD # Perform the cd command to that directory
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
