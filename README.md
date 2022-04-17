# forceumount
Forcefully umount devices.

All processes and threads holding devices are killed. First gently by SIGTERM and after a timeout with SIGKILL.

usage: forceumount.sh {one_or_more_devices}

The device name can be a block device (i.e. /dev/sdc), a loop back device (i.e. /dev/loop0) or name of an iso-file (i.e. /home/user/Downloads/ubuntu.iso).

Tested with Ubuntu.
