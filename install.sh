#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

echo "This will create symlinks and destroy any conflicting configs already in place.";
read -p "Continue? [y/N] " choice

case "$choice" in 
  Y|y|yes )
        echo "Moving to Home directory...";
        cd ~;
        
        echo "Linking bash...";
        if [ -f .bashrc ];
        then
            rm .bashrc;
        fi
        ln -s $DIR/.bashrc .bashrc;
        
        echo "Linking vim...";
        if [ -f .vimrc ];
        then
            rm .vimrc;
        fi
        ln -s $DIR/.vimrc .vimrc;
        if [ -d .vim ];
        then
            rm -rf .vim;
        fi
        ln -s $DIR/.vim .vim;
        
        echo "Linking Git...";
        if [ -f .gitconfig ];
        then
            rm .gitconfig;
        fi
        ln -s $DIR/.gitconfig .gitconfig;
        
        echo "Linking tmux...";
        if [ -f .tmux.conf ];
        then
            rm .tmux.conf;
        fi
        ln -s $DIR/.tmux.conf .tmux.conf;
        
        echo "Hotswapping bash...";
        source .bashrc;
        
        echo "Done! Exiting."
    ;;
  * ) echo "Aborted!";;
esac
