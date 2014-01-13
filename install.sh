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
#  ----------  -------------- ----------------------------------------------
#  2014-01-13  agrosinger     Added support for using the ZIP instead of git
#  2014-01-04  agrosinger     Updated to two mode operation
################################################################################

DOTFILES_DIR="${HOME}/.dotfiles"
GIT_REPO_BASE="https://github.com/tgrosinger/dotfiles"
GIT_REPO="${GIT_REPO_BASE}.git"
REPO_ZIP="${GIT_REPO_BASE}/archive/master.zip"

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

    echo "Moving to Home directory..."
    pushd ${home} > /dev/null

    echo "Adding id_rsa.pub to authorized keys if necessary"
    if [ ! -d .ssh ]; then
        mkdir .ssh
    fi
    if [ ! -e ".ssh/authorized_keys" ]; then
        cp ${REPO_DIR}/.ssh/id_rsa.pub .ssh/authorized_keys
    elif ! grep -f ${REPO_DIR}/.ssh/id_rsa.pub .ssh/authorized_keys; then
        cat ${REPO_DIR}/.ssh/id_rsa.pub >> .ssh/authorized_keys
    fi
    
    echo "Linking shell configs..."
    linkFile ".bashrc"

    echo "Linking vim..."
    linkFile ".vimrc"
    createDirectory ".vim"
    createDirectory ".vim/swaps"
    createDirectory ".vim/backups"
    
    echo "Linking Git..."
    linkFile ".gitconfig"
    
    echo "Linking tmux..."
    linkFile ".tmux.conf"

    echo "Linking inputrc..."
    linkFile ".inputrc"

    popd > /dev/null
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
    if which git; then
        # Git is installed, clone the repository using read-only url
        if [ -d ${DOTFILES_DIR} ]; then
            
            if [ -d ${DOTFILES_DIR}/.git ]; then
                echo "Updating dotfiles repository in ${DOTFILES_DIR}"
                pushd ${DOTFILES_DIR} > /dev/null
                git pull > /dev/null
                popd > /dev/null
            else
                echo "Cloning dotfiles repository to ${DOTFILES_DIR}"
                rm -rf ${DOTFILES_DIR}
                git clone ${GIT_REPO} ${DOTFILES_DIR}
            fi
        else
            echo "Cloning dotfiles repository to ${DOTFILES_DIR}"
            git clone ${GIT_REPO} ${DOTFILES_DIR}
        fi
    else
        # Git is not installed, download the zip and extract
        if ! which wget || ! which unzip; then
            echo "You must have either git or wget and unzip installed. Please install one before continuing."
            exit 1
        fi

        if [ -d ${DOTFILES_DIR} ]; then
            rm -rf ${DOTFILES_DIR}
        fi

        wget -q -O /tmp/dotfiles.zip ${REPO_ZIP}
        unzip /tmp/dotfiles.zip -q -d ${DOTFILES_DIR}
        rm /tmp/dotfiles.zip
    fi
    
    REPO_DIR="${DOTFILES_DIR}"
    performSetup ${HOME}
    echo "Done! Restart your shell to see changes"
fi
