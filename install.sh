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
        ln -sfn $DIR/.vim ~/.config/nvim

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

echo "Getting dependencies..."
cd $DIR
git submodule update

if [ ! -d /usr/share/fonts/truetype/SourceCodePro ]; then
    echo "Installing fonts..."
    sudo apt-get install -y fonts-roboto
    sudo cp -r $DIR/plugins/fonts/SourceCodePro /usr/share/fonts/truetype/
    sudo cp -r $DIR/plugins/Font-Awesome/fonts /usr/share/fonts/truetype/
    sudo fc-cache -fv
    read -p "Installed. Select Source Code Pro as mono and Roboto as sans-serif. [Enter] to continue"
fi

if [ ! -f /etc/apt/sources.list.d/snwh-pulp-trusty.list ]; then
    echo "Installing theme..."
    sudo add-apt-repository ppa:snwh/pulp
    sudo apt-get update
    sudo apt-get install -y paper-icon-theme paper-gtk-theme lxappearance gtk-chtheme qt4-qtconfig
    read -p "Installed. Select Paper in lxappearance and gtk-chtheme. Select GTK+ in qt4-qtconfig. [Enter] to continue"
fi

if ! type i3 >/dev/null 2>&1; then
    echo "Installing i3..."
    sudo echo "deb http://debian.sur5r.net/i3/ $(lsb_release -c -s) universe" >> /etc/apt/sources.list
    sudo apt-get update
    sudo apt-get --allow-unauthenticated install sur5r-keyring
    sudo apt-get update
    sudo apt-get install -y i3
    sudo echo "*/1 * * * * $DIR/.i3/i3batwarn.sh" | sudo tee /etc/cron.d/i3batwarn > /dev/null
    echo "Installed."
fi

if ! type nvim >/dev/null 2>&1; then
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
    sudo apt-get install -y python-pip
    pip install powerline-status
    echo "Installed."
fi

if ! type fzf >/dev/null 2>&1; then
    echo "Installing FZF..."
    $DIR/plugins/fzf/install
    echo "Installed."
fi
