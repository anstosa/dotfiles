#!/bin/bash

################################################################################
#Copyright (C) 2013 Tony Grosinger. All rights reserved.
#
#Description:
# This script can be run in two modes depending on the file structure of the
# current working directory or the arguments passed to it.
# 
# Mode 1: From within a cloned repository or downloaded snapshot with all files
#         already present and ready to be symlinked
#
# Mode 2: Standalone or through Curl in which case all required files will be 
#         downloaded automatically to `~/.dotfiles` before creating symlinks.
#
#Change History:
#  Date        Author         Description
#  ----------  -------------- ------------------------------------
#  2014-01-04  agrosinger     Updated to two mode operation
################################################################################
  

################################################################################
# Define functions
################################################################################

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

# Perform the actual work of copying files and creating symlinks. 
# Requires a home directory argument.
function performSetup() {
    if [ ${#} != 1 ]; then 
        echo "Must pass home directory to ${FUNCNAME}"
        exit 1
    fi
    home=${1}

    echo "Moving to Home directory...";
    pushd ${home};

    echo "Adding id_rsa.pub to authorized keys if necessary"
    if [ ! -e ".ssh/authorized_keys" ] ; then
        cp ${REPO_DIR}/.ssh/id_rsa.pub .ssh/authorized_keys
    elif ! grep -q `cat ${REPO_DIR}/.ssh/id_rsa.pub` ".ssh/authorized_keys"; then
        cat ${REPO_DIR}/.ssh/id_rsa.pub >> .ssh/authorized_keys
    fi
    
    echo "Linking shell configs...";
    linkFile ".bashrc"

    echo "Linking vim...";
    linkFile ".vimrc"
    createDirectory ".vim"
    createDirectory ".vim/swaps"
    createDirectory ".vim/backups"
    
    echo "Linking Git...";
    linkFile ".gitconfig"
    
    echo "Linking tmux...";
    linkFile ".tmux.conf"

    echo "Linking inputrc..."
    linkFile ".inputrc"

    popd
}

################################################################################
# Initialize (Determine mode)
################################################################################

# Determine which mode we are running in. (Is the file in the current directory?)
if [ -f install.sh ]; then
    echo "Running in Mode 1: Already cloned repository"
    REPO_DIR="$( cd "$( dirname "$0" )" && pwd )"

    echo "This will create symlinks and destroy any conflicting configs already in place.";
    read -p "Continue? [y/N] " choice

    # Perform the logic
    case "$choice" in 
        Y|y|yes )
            performSetup ${HOME}
            echo "Done! Restart your shell to see changes"
        ;;
        * ) echo "Aborted!";;
    esac
else
    echo "Running in Mode 2: Direct from Curl"

    # Make sure git is installed. Exit if it isn't.
    if ! which git; then
        echo "Please install git before continuing."
        echo "Alternatively, download the files and run manually from https://github.com/tgrosinger/dotfiles/archive/master.zip"
        exit 1
    fi

    # Clone the repository into current location using readonly url.
    echo "Cloning dotfiles repository to ${HOME}/.dotfiles"
    if [ -d ${HOME}/.dotfiles ]; then
        pushd ${HOME}/.dotfiles
        git pull
        popd
    else
        git clone https://github.com/tgrosinger/dotfiles.git ${HOME}/.dotfiles
    fi
    REPO_DIR="${HOME}/.dotfiles"
    performSetup ${HOME}
    echo "Done! Restart your shell to see changes"
fi
