Tony's DotFiles
===============

This is a collection of all the files that I want very easily available on any new machine that I sit down at. The install script is designed to be run either from the cloned repository or as a stand-alone script through curl. See the usage details for examples.

WARNING
-------

The install script provided with these dotfiles is destructive and will overwrite files without asking. To ensure that you do not lose anything important please backup your .bashrc, .gitconfig, .gitignore, .inputrc, .tmux.conf, and .vimrc files in your home directory.

I can not be held responsible if you lose any important data.

Usage
-----

**Method 1**

The first method requires cloning the repository and running the install script manually.

	git clone git@github.com:tgrosinger/dotfiles.git ~/.dotfiles
	cd ~/.dotfiles
	./install.sh

**Method 2**

The second method does not require cloning the repository however it does require that Git and Curl is installed on the target machine.

	\curl -sSL https://raw.github.com/tgrosinger/dotfiles/master/install.sh | bash
