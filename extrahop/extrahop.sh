#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

if [ $1 == "start" ] ; then
	echo "Starting VPN"
	cd /etc/openvpn
	sudo openvpn --config extrahop.conf &
	((count = 100))
	while [[ $count -ne 0 ]] ; do
	    ping -c 1 trunkium.sea.i.extrahop.com
	    rc=$?
	    if [[ $rc -eq 0 ]] ; then
		((count = 1))
	    fi
	    ((count = count - 1))
	done

	if [[ $rc -eq 0 ]] ; then
		echo "Setting up DNS"
        sudo ln -fs ${DIR}/extrahop.resolv.conf /etc/resolv.conf
	fi
else
	echo "Stopping VPN"
	sudo killall -15 openvpn
	echo "Resetting DNS"
	sudo ln -fs /run/resolvconf/resolv.conf /etc/resolv.conf
fi

