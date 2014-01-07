# Prompt
PS1="\n[ \w ]--[\$(ls -1 | wc -l | sed 's: ::g') files]\n\h\$ "

# Navigation
if [[ ! "$OSTYPE" == darwin* ]];
then 
    alias ls="ls --color=auto"
fi
alias c="clear"
alias ..="cd .."
alias la="ls -lha"
alias rmr="rm -r"

# Applications
alias tmux="tmux -2"
alias grep="grep --color=auto"

# Maven
alias mvnc="mvn clean"
alias mvnp="mvn clean package"
alias mvni="mvn clean install"
alias mvna="mvn clean assembly:assembly"
alias mvnd="mvn clean dependency:copy-dependencies"

# Tar
alias tar-gz="tar xzvf"
alias tar-bz="tar xjvf"
alias tar-xz="tar Jxvf"

# Computer information & control
alias df="df -h"
alias reboot="echo That would be bad..."
alias shutdown="echo Don't do that"

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

