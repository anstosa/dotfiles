#!/bin/bash

DIR="$( cd "$( dirname "$0" )" && pwd )"

echo "Create symlinks and destroy any conflicting configs already in place."
read -p "Continue? [y/N] " choice

function makeLink() {
    ln -sfn $DIR/$1 $1
}

case "$choice" in
  Y|y|yes )
        echo "Moving to Home directory..."
        cd ~;

        echo "Linking bash..."
        makeLink .bashrc

        echo "Linking vim..."
        makeLink .vim
        makeLink .vimrc

        echo "Linking Git..."
        makeLink .gitconfig

        echo "Linking tmux..."
        makeLink .tmux.conf

        echo "Linking inputrc..."
        makeLink .inputrc

        echo "Linking powerline..."
        ln -sfn $DIR/powerline ~/.config/powerline

        echo "Hotswapping bash config..."
        source .bashrc

        echo "Linked."
    ;;
  * ) echo "Skipping link"
esac

echo "Getting dependencies..."
cd $DIR
git submodule update

if ! type tmux >/dev/null 2>&1; then
    echo "Installing tmux..."
    sudo apt-get install -y python-software-properties software-properties-common
    sudo add-apt-repository -y ppa:pi-rho/dev
    sudo apt-get update
    sudo apt-get install -y tmux
    echo "Installed."
fi

if ! type powerline >/dev/null 2>&1; then
    echo "Installing powerline..."
    sudo apt-get install -y python3-pip
    sudo -H pip3 install --upgrade pip
    sudo -H pip3 install powerline-status
    echo "Installed."
fi

if ! type fzf >/dev/null 2>&1; then
    echo "Installing FZF..."
    $DIR/plugins/fzf/install
    echo "Installed."
fi
