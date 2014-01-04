Tony's DotFiles
===============

This is a collection of all the files that I want very easily available on any new machine that I sit down at. The install script is designed to be run either from the cloned repository or as a stand-alone script through curl. See the usage details for examples.

Usage
-----

** Method 1 **

The first method requires cloning the repository and running the install script manually.

	git clone git@github.com:tgrosinger/dotfiles.git ~/.dotfiles
	cd ~/.dotfiles
	./install.sh

** Method 2 **

The second method does not require cloning the repository however it does require that Git and Curl is installed on the target machine.

	\curl -sSL https://raw.github.com/tgrosinger/dotfiles/master/install.sh | bash
