#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

echo "This will create symlinks and destroy any conflicting configs already in place."
read -p "Continue? [y/N] " choice

function makeLink() {
    ln -sf $DIR/$1 $1
}

case "$choice" in
  Y|y|yes )
        echo "Moving to Home directory..."
        cd ~;

        echo "Linking bash..."
        makeLink .bashrc

        echo "Linking vim..."
        makeLink .vimrc
        makeLink .vim

        echo "Linking Git..."
        makeLink .gitconfig

        echo "Linking tmux..."
        makeLink .tmux.conf

        echo "Linking i3"
        makeLink .i3
        makeLink .i3status.conf

        echo "Linking inputrc..."
        makeLink .inputrc

        echo "Linking powerline..."
        ln -sf $DIR/powerline ~/.config/powerline

        echo "Hotswapping bash config..."
        source .bashrc

        echo "Done! Exiting."
    ;;
  * ) echo "Aborted!"
esac
