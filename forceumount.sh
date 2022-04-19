#!/bin/bash

# set -x

help=0
declare -a blkdevices

[ $# == 0 ] && help=1

while [ $# -gt 0 ] ; do
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
    echo "$0 {one_or_more_devices}"
    echo
    echo "\
Try to kill processes and threads holding a device and then \
deactivate it."
    echo "Non existing devices are ignored."
    echo "\
The device name can be a block device (i.e. /dev/sdc), a loop back \
device (i.e. /dev/loop0) or name of an iso-file \
(i.e. /home/user/Downloads/ubuntu.iso)."
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
    
    lsblk -n -o MOUNTPOINT "${dev}" |
    while IFS= read -r f ; do
        if [ "$f" != "" ] ; then
            for (( i=0 ; i<30 ; i++ )) ; do 
                fuser -m "$f" 2>/dev/null | awk '{print $0}' | tr ' ' '\n' | grep -v -E '^$' |
                while IFS= read -r g ; do
                    if [ "$g" != "" ] ; then
                        kill -$sig -- "-$g" || true
                    fi
                done
                echo -n "."
                
                sleep 1s
                moretokill=$(lsblk -n -o MOUNTPOINT "${dev}" | xargs -r -I '{}' -- fuser '{}' 2>/dev/null | tr ' ' '\n' | grep -v '^$' | wc -l)
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
        
        # swap
        lsblk -n -o MOUNTPOINT "${umountdev}" | while IFS= read -r f ; do if [ "$f" != "" ] ; then swapon --show=NAME --noheadings | grep -E "^$f" | xargs -I '{}' -- swapoff '{}' ; fi ; done
        
        # non block devices
        lsblk -n -o MOUNTPOINT "${umountdev}" | while IFS= read -r f ; do if [ "$f" != "" ] ; then df -a --output=source,target | awk -v mountpoint="$f" '{if(substr($2,1,length(mountpoint))==mountpoint){print $2}}' | grep -E '^/' | sort -u | awk '{printf("%04d%s\n",length($0),$0)}' | sort -r -n | awk '{print substr($0,5)}' | xargs -I '{}' -- umount '{}' ; fi ; done
        
        # meant for loop devices
        lsblk -n -p -l "${umountdev}" | tac | awk '{print $1}' | xargs -r -I '{}' -- umount '{}' 2>/dev/null
        
        # deactivate loop devices
        lsblk -n -p -l "${umountdev}" | tac | awk '{print $1}' | xargs -r -I '{}' -- losetup -d '{}' 2>/dev/null
        
        # the rest
        lsblk -n -p -l "${umountdev}" | tac | awk '{print $1}' | xargs -r -I '{}' -- blkdeactivate -d force,retry -u -l wholevg -m disablequeueing -r wait '{}'
    fi
done

exit 0

