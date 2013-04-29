#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

echo "This will create symlinks and destroy any conflicting configs already in place.";
read -p "Continue? [y/N] " choice

function makeLink() {
    if [ -f $1 ]; then
        rm $1;
    elif [ -d $1 ]; then
        rm -rf $1
    fi
    ln -s $DIR/$1 $1;
}

case "$choice" in 
  Y|y|yes )
        echo "Moving to Home directory...";
        cd ~;
        
        echo "Linking bash...";
        makeLink .bashrc;
        
        echo "Linking vim...";
        makeLink .vimrc
        makeLink .vim
        
        echo "Linking Git...";
        makeLink .gitconfig
        
        echo "Linking tmux...";
        makeLink .tmux.conf
        makeLink .tmux.conf.nested

        echo "Linking inputrc..."
        makeLink .inputrc
        
        echo "Hotswapping bash config...";
        source .bashrc;
        
        echo "Done! Exiting."
    ;;
  * ) echo "Aborted!";;
esac
