#!/bin/bash

# Initialize any submodules
git submodule init
git submodule update

echo "This will create symlinks and destroy any conflicting configs already in place.";
read -p "Continue? [y/N] " choice

# Helper function to remove old file and link the new one
DIR="$( cd "$( dirname "$0" )" && pwd )"
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

# Perform the logic
case "$choice" in 
  Y|y|yes )
        echo "Moving to Home directory...";
        cd ~;
        
        echo "Linking shell configs...";
        linkFile .zshrc
        linkFile .bashrc
        linkFile .shell_settings

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

        echo "Linking autoenv..."
        linkFile .autoenv
        
        echo "Done! Restart your shell to see changes"
    ;;
  * ) echo "Aborted!";;
esac
