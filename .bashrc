# ~/.bashrc
GOPATH=$HOME/go
PATH=$HOME/.local/bin:$HOME/.dotfiles/bin:$PATH:$GOPATH/bin
export PYTHONPATH=$PYTHONPATH:$HOME
export LANG=en_US.UTF-8
export PATH="/home/ansto/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# History
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

Color_Off='\e[0m'       # Text Reset
Black='\e[0;30m'        # Black
White='\e[0;37m'        # White
On_Black='\e[40m'       # Black
On_White='\e[47m'       # White

# prevent Ctrl-S from being a little bitch
[[ $- == *i* ]] && stty -ixon

alias sl=ls
alias ls='ls --color --group-directories-first -FAv'
alias ll='ls --color --group-directories-first -FAvlhG'
alias grep='grep --color=auto'
alias fix='stty sane'

alias update='sudo apt-get update && sudo apt-get upgrade && sudo apt-get dist-upgrade && sudo apt-get install update-manager-core && sudo apt-get -f install && sudo apt-get autoremove && sudo apt-get autoclean'

# TMUX
alias tmux='TERM=screen-256color-bce tmux -2 -u'
alias ta='tmux attach -d -t'
alias fzf='fzf-tmux'

# Powerline
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/local/lib/python3.5/dist-packages/powerline/bindings/bash/powerline.sh
source ~/.dotfiles/tmuxinator.bash
if [[ -z "$TMUX" && $- == *i* ]] ;then
    ID="`tmux ls | grep -vm1 attached | cut -d: -f1`" # get the id of a deattached session
    if [[ -z "$ID" ]] ;then # if not available create a new one
        tmux new-session
    else
        tmux attach-session -d -t "$ID" # if available attach to it
    fi
fi

# Prompt
PS1="\[$Black$On_White\]\W \$\[$Color_Off\] "
PS1="$PS1"'$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD")'

# Source plugins
source ~/.dotfiles/cdhist.sh

# Source local
source ~/.bashrc_local

# Ruby
if [[ -d ${HOME}/.rvm ]]; then
    PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
    source ${HOME}/.rvm/scripts/rvm
fi

export FZF_DEFAULT_COMMAND='
 (git ls-files $(git rev-parse --show-toplevel) --cached --exclude-standard --others ||
  find * -name ".*" -prune -o -type f -print -o -type l -print) 2> /dev/null'
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

strip_diff_leading_symbols(){
    color_code_regex="(\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K])"

    # simplify the unified patch diff header
    sed -r "s/^($color_code_regex)diff --git .*$//g" | \
        sed -r "s/^($color_code_regex)index .*$/\n\1$(rule)/g" | \
        sed -r "s/^($color_code_regex)\+\+\+(.*)$/\1+++\5\n\1$(rule)\x1B\[m/g" |\

    # actually strips the leading symbols
        sed -r "s/^($color_code_regex)[\+\-]/\1 /g"
}
export -f strip_diff_leading_symbols

## Print a horizontal rule
rule () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}
