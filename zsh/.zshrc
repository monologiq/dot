# ZSH Parameters
# See `man zshparam`

HISTFILE="$XDG_DATA_HOME/zsh_history"
SAVEHIST="10000"
HISTSIZE="$(printf %.0f $(($SAVEHIST * 1.2)))"

autoload -Uz compinit
compinit

# ZSH Parameters
# See `man zshparam`

HISTFILE="$XDG_DATA_HOME/zsh_history"
SAVEHIST="10000"
HISTSIZE="$(printf %.0f $(($SAVEHIST * 1.2)))"

autoload -Uz compinit
compinit