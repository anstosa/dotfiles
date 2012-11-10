#
# ~/.bashrc
#

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
alias ls='ls -a --color=auto'
alias ll='ls -l'
alias up='cd ../'
alias clear='clear;ls;'

# Git
alias gs='git status '
alias ga='git add '
alias gb='git branch '
alias gc='git commit'
alias gd='git diff'
alias go='git checkout '
alias gh='git hist '

# TMUX
alias tmux='tmux -2'
alias patched='cp ~/.custom/tmux-powerline/config.sh.patched ~/.custom/tmux-powerline/config.sh'
alias unpatched='cp ~/.custom/tmux-powerline/config.sh.unpatched ~/.custom/tmux-powerline/config.sh'

# Update Forum
alias uf='sudo cp ~/forum/htdocs/const/* /usr/local/lib/python2.7/dist-packages/askbot/const/; sudo cp ~/forum/htdocs/models/* /usr/local/lib/python2.7/dist-packages/askbot/models/; sudo cp ~/forum/htdocs/views/* /usr/local/lib/python2.7/dist-packages/askbot/views/; echo "Forum source updated. Server restart my be necessary."'

# Prompt
PS1="\[$Black$On_White\]\W \$\[$Color_Off\] "
PS1="$PS1"'$([ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD")'
