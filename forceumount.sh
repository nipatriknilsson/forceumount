#!/bin/bash

# set -x

help=0
declare -a blkdevices

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            help=1
            shift
            ;;
        
        -*)
            help=1
            shift
            ;;
        
        *)
            blkdevices+=( "$1" )
            shift
            ;;
    esac
done

if [ "$help" == "1" ] ; then
    echo "$0 {blockdevice} [blockdevice]..."
    echo "Try to kill processes holding a block device and then deactivate the device."
    echo "Nonexisting blockdevices are ignored"
    echo
    echo "Copyright 2022 Patrik Nilsson. MIT License."
    exit 1
fi

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 255
fi

sendkill()
{
    dev=$1
    sig=$2
    
    lsblk -r -n -o MOUNTPOINT "${dev}" |
    while IFS= read -r f ; do
        if [ "$f" != "" ] ; then
            for (( i=0 ; i<30 ; i++ )) ; do 
                fuser -m "$f" 2>/dev/null | awk '{print $0}' | tr -d ' ' | grep -v -E '^$' |
                while IFS= read -r g ; do
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

for blkdevice in "${blkdevices[@]}" ; do
    if [ -b "$blkdevice" ]; then
        umountdev="$blkdevice"
    else
        umountdev=$(losetup --raw --list NAME -n -j "$blkdevice" | awk '{print $1}')
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
done

exit 0

