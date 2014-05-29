# Prompt
PS1="\n[ \w ]--[\$(ls -1 | wc -l | sed 's: ::g') files]\n\h\$ "

# Navigation
if [[ ! "$OSTYPE" == darwin* ]];
then 
    alias ls="ls --color=auto"
fi
alias c="clear"
alias ..="cd ..;"
alias la="ls -lha"
alias rmr="rm -r"
alias please="sudo !!"

# Applications
alias tmux="tmux -2"
alias grep="grep --color=auto"

# Adding applications to path
if [[ -d ${HOME}/bin ]];
then
    export PATH=$PATH:${HOME}/bin
fi

if [[ -d ${HOME}/.rvm ]];
then
    PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
fi

# Maven
source ~/bin/maven-illuminate.sh
alias mvnc="mvn-c clean"
alias mvnp="mvn-c clean package"
alias mvni="mvn-c clean install"
alias mvna="mvn-c clean assembly:assembly"
alias mvnd="mvn-c clean dependency:copy-dependencies"

# Tar
alias tar-gz="tar xzvf"
alias tar-bz="tar xjvf"
alias tar-xz="tar Jxvf"

# Computer information & control
alias df="df -h"
alias reboot="echo That would be bad..."
alias shutdown="echo Don't do that"

# Ruby
if [[ -f ~/.rvm/scripts/rvm ]];
then
    source ~/.rvm/scripts/rvm
fi

# Functions

# (f)ind by (n)ame
# usage: fn foo
# to find all files containing 'foo' in the name
function fn() { 
	if [ $# -eq 2 ]; then
		sudo find $1 -name $2
	elif [ $# -eq 1 ]; then
		find `pwd` -name $1
	fi
}

# Backup and Move TiddlyWiki Download
# usage: wiki-move
function wiki-move() {
    if [[ -f ${HOME}/Dropbox/wiki.htm ]] && [[ -f ${HOME}/Downloads/wiki.htm ]];
    then
        echo "Backing up existing wiki and moving new one."
        mv ${HOME}/Dropbox/wiki.htm ${HOME}/Dropbox/wiki.htm.old
        mv ${HOME}/Downloads/wiki.htm ${HOME}/Dropbox/wiki.htm
        echo "Successfully replaced"
    fi
}

