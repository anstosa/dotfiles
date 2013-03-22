# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd
bindkey -v
bindkey '^R' history-incremental-search-backward
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/tony/.zshrc'

autoload -Uz compinit promptinit
compinit
promptinit
prompt walters
# End of lines added by compinstall

# Fix the home and end keys
typeset -A key
key[Home]=${terminfo[khome]}
key[End]=${terminfo[kend]}
[[ -n "${key[Home]}"    ]]  && bindkey  "${key[Home]}"    beginning-of-line
[[ -n "${key[End]}"     ]]  && bindkey  "${key[End]}"     end-of-line

precmd () {
    # tmux support
    PROMPT="$PS1"`[ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD"`
}

source ~/.shell_settings