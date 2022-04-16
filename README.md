# forceumount
Forcefully umount devices.

All processes and threads holding devices are killed. First gently by SIGTERM and after a timeout with SIGKILL.

usage: forceumount.sh {one_or_more_devices}

Tested with Ubuntu.
