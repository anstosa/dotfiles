#!/bin/bash

# Make sure git is installed. Exit if it isn't
if which git; then
    echo "Please install git before continuing"
    exit 1
fi

REPO_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Remove a file if it exists then create a symlink to the one contained in ${REPO_DIR}
function linkFile() {
    if [ -e $1 ]; then rm -rf $1; fi
    ln -s ${REPO_DIR}/$1 $1;
}

# Create a directory named by first parameter. Delete directory first if it already exists.
function createDirectory() {
    if [ -d $1 ]; then rm -rf $1; fi
    mkdir $1
}

echo "This will create symlinks and destroy any conflicting configs already in place.";
read -p "Continue? [y/N] " choice

# Perform the logic
case "$choice" in 
  Y|y|yes )
        echo "Moving to Home directory...";
        cd ~;

        echo "Adding id_rsa.pub to authorized keys if necessary"
        if [ ! -e ".ssh/authorized_keys" ] ; then
            cp ${REPO_DIR}/.ssh/id_rsa.pub .ssh/authorized_keys
        elif ! grep -q `cat ${REPO_DIR}/.ssh/id_rsa.pub` ".ssh/authorized_keys"; then
            cat ${REPO_DIR}/.ssh/id_rsa.pub >> .ssh/authorized_keys
        fi
        
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

        echo "Linking inputrc..."
        linkFile .inputrc

        echo "Done! Restart your shell to see changes"
    ;;
  * ) echo "Aborted!";;
esac
