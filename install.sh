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
        makeLink .nvim
        makeLink .nvimrc

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
        ln -sfn $DIR/powerline ~/.config/powerline

        echo "Hotswapping bash config..."
        source .bashrc

        echo "Linked."
    ;;
  * ) echo "Skipping link"
esac

if type nvim >/dev/null 2>&1; then
    echo "Found Neovim."
else
    echo "Installing NeoVim..."
    sudo add-apt-repository ppa:neovim-ppa/unstable
    sudo apt-get update
    sudo apt-get install neovim python-dev python-pip python3-dev python3-pip
    sudo pip3 install neovim

    echo "Installed. Setting defaults"
    sudo update-alternatives --install /usr/bin/vi vi /usr/bin/nvim 60
    sudo update-alternatives --config vi
    sudo update-alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
    sudo update-alternatives --config vim
    sudo update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 60
    sudo update-alternatives --config editor
    echo "Defaults set."
fi

if type tmux >/dev/null 2>&1; then
    echo "Found tmux"
else
    echo "Installing tmux..."
    sudo apt-get install -y python-software-properties software-properties-common
    sudo add-apt-repository -y ppa:pi-rho/dev
    sudo apt-get update
    sudo apt-get install -y tmux
    echo "Installed."
fi

if type powerline >/dev/null 2>&1; then
    echo "Found powerline"
else
    echo "Installing powerline..."
    sudo apt-get install -y python-pip
    pip install powerline-status
    echo "Installed. Don't forget to patch your fonts"
fi

if type fzf >/dev/null 2>&1; then
    echo "Found FZF"
else
    echo "Installing FZF..."
    $DIR/plugins/fzf/install
    echo "Installed."
fi
