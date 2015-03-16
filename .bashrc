# ~/.bashrc
PATH=$HOME/.local/bin:$PATH
export LANG=en_US.UTF-8

# History
HISTSIZE=1000
HISTFILESIZE=2000
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
stty -ixon

alias ls='ls --color=auto'
alias ll='ls -alF'
alias up='cd ../'
alias grep='grep --color=auto'

# Git
alias gs='git status '
alias ga='git add '
alias gc='git commit'
alias gaa='git add -A .'
alias gd='git diff'
alias gdh="git diff | haste | sed -e 's/$/.diff/' | xclip -selection c"
alias gsh="git show | haste | sed -e 's/$/.diff/' | xclip -selection c"
alias gh='git hist '
alias gl='git log '
alias gad='git ls-files --deleted | xargs git rm'

# Work
alias extrahop='/home/ansel/.ansel/extrahop.sh'

# TMUX
alias tmux='TERM=screen-256color-bce tmux -2 -u'
alias ta='tmux attach -d -t'
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/local/lib/python2.7/dist-packages/powerline/bindings/bash/powerline.sh
source ~/.ansel/tmuxinator.bash
if [[ -z "$TMUX" ]] ;then
    ID="`tmux ls | grep -vm1 attached | cut -d: -f1`" # get the id of a deattached session
    if [[ -z "$ID" ]] ;then # if not available create a new one
        tmux new-session
    else
        tmux attach-session -d -t "$ID" # if available attach to it
    fi
fi

# Editor
export EDITOR='vim'
if [ -e /usr/bin/vimx ]; then alias vim='/usr/bin/vimx'; fi

# Prompt
PS1="\[$Black$On_White\]\W \$\[$Color_Off\] "
PS1="$PS1"'$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD")'

# Source scripts
source ~/.ansel/cdhist.sh

# Source local
source ~/.bashrc_local

PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
