#!/bin/bash

# Initialize any submodules
git submodule init
git submodule update

DIR="$( cd "$( dirname "$0" )" && pwd )"
OS="$(lsb_release -si)"

# Helper function to remove old file and link the new one
function linkFile() {
    if [ -f $1 ]; then
        rm $1;
    elif [ -d $1 ]; then
        rm -rf $1
    fi
    ln -s $DIR/$1 $1;
}

function createDirectory() {
    if [ -d $1 ]; then
        rm -rf $1
    fi
    
    mkdir $1
}

echo "This will create symlinks and destroy any conflicting configs already in place.";
read -p "Continue? [y/N] " choice

# Perform the logic
case "$choice" in 
  Y|y|yes )
        echo "Moving to Home directory...";
        cd ~;
        
        echo "Linking shell configs...";
        linkFile .bashrc

        echo "Linking vim...";
        linkFile .vimrc
        createDirectory ~/.vim
        createDirectory ~/.vim/swaps
        createDirectory ~/.vim/backups
        
        echo "Linking Git...";
        linkFile .gitconfig
        
        echo "Linking tmux...";
        linkFile .tmux.conf
        linkFile .tmux-powerline

        echo "Linking inputrc..."
        linkFile .inputrc

        echo "Done! Restart your shell to see changes"
    ;;
  * ) echo "Aborted!";;
esac
