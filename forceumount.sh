#!/bin/bash

# set -x

umountdev=$1

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 255
fi

if [ $# -eq 0 ] ; then
    echo "$0 {blockdevice} [blockdevice]..."
    echo "Try to kill processes holding a block device and then deactivate it"
    echo "Copyright 2022 Patrik Nilsson. MIT License."
fi

sendkill()
{
    dev=$1
    sig=$2
    
    lsblk -r -n -o MOUNTPOINT "${dev}" |
    while IFS= read -r f ; do
        if [ "$f" != "" ] ; then
            for (( i=0 ; i<30 ; i++ )) ; do 
                fuser -m "$f" 2>/dev/null |
                while read -d " " g ; do
                    if [ "$g" != "" ] ; then
                        kill -$sig -- "-$g" || true
                    fi
                done
                echo -n "."
                
                sleep 1s
                moretokill=$(lsblk -r -n -o MOUNTPOINT "${dev}" | xargs -r -I '{}' -- fuser '{}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | wc -l)
                if [ "$moretokill" == "0" ] ; then
                    break
                fi
            done
        fi
    done
}

while [ $# -gt 0 ]; do
    if [ -b "$1" ]; then
        umountdev=$1
    else
        umountdev=$(losetup --raw --list NAME -n -j "$1" | awk '{print $1}')
    fi

    if [ "$umountdev" != "" ]; then
        echo -n "Sending SIGTERM to processes holding device: "
        sendkill "${umountdev}" TERM
        echo " Done!"
        
        echo -n "Sending SIGKILL to processes holding device: "
        sendkill "${umountdev}" KILL
        echo " Done!"
        
        lsblk -r -n -o MOUNTPOINT "${umountdev}" | while IFS= read -r f ; do if [ "$f" != "" ] ; then swapon --show=NAME --noheadings | grep -E "^$f" | xargs -I '{}' -- swapoff '{}' ; fi ; done
        
        lsblk -n -p -l "${umountdev}" | tac | awk '{print $1}' | xargs -r -I '{}' -- blkdeactivate -d force,retry -u -l wholevg -m disablequeueing -r wait '{}'
    fi
    
    shift
done

exit 0

