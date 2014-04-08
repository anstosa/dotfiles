# ~/.bashrc
PATH=$HOME/.local/bin:$PATH

# History
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Reset
Color_Off='\e[0m'       # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

alias :q='exit'
alias ls='ls --color=auto'
alias l='ls'
alias sl='ls'
alias la='ls -a'
alias ll='ls -alF'
alias up='cd ../'
alias clear='clear;ls;'
alias grep='grep --color=auto'

# Git
alias gs='git status '
alias ga='git add '
alias gaa='git add -A .'
alias gai='git add -p'
alias gb='git branch '
alias gc='git commit'
alias gd='git diff'
alias go='git checkout '
alias gh='git hist '
alias gi='git update-index --assume-unchanged '
alias gni='git update-index --no-assume-unchanged '
alias gl='git log '
alias gad='git ls-files --deleted | xargs git rm'
alias gp='git pull '
alias gpp='git push '

# TMUX
alias tmux='tmux -2'
alias ta='tmux attach -d -t'
alias tn='unset TMUX; tmux; tmux source ~/.tmux.conf.nested'
. ~/powerline/bindings/bash/powerline.sh

# Prompt
PS1="\[$Black$On_White\]\W \$\[$Color_Off\] "
PS1="$PS1"'$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD")'

# Source scripts
source ~/.custom/cdhist.sh

# Source local
source ~/.bashrc_local

PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
