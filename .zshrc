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

precmd () {
    # tmux support
    PROMPT="$PS1"`[ -n "$TMUX" ] && tmux setenv TMUXPWD_$(tmux display -p "#I_#P") "$PWD"`
}

# SSH
alias aws="ssh -i ~/.ssh/capstone.pem ec2-user@ec2-174-129-49-253.compute-1.amazonaws.com"

# Navigation
alias -r c="clear & ls -lha"
alias -r ..="cd .."
alias ls="ls --color=auto"
alias la="ls -lha"

# Applications
alias mongod="mongod -f /etc/mongodb.conf"
alias tmux="tmux -2"

# Computer control
alias -r reboot="echo That would be bad..."
alias -r shutdown="echo Don't do that"

# Git
alias gp="git pull"
alias ga="git add "
alias gl="git log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short"
alias gc="git commit -m "
alias gs="git status"
alias gpp="git push"

# Updating
alias -r update="sudo pacman -Syu"
alias pacman="sudo pacman"
