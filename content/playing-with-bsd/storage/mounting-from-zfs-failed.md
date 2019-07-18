---
title: "Mounting ZFS Root failed when an external USB drive is connected"
date: 2019-07-18T19:08:00+09:00
draft: true
tags: [ "storage", "zfs", "usb", "ufs", "freebsd" ]
toc: true
---
Last week, one of my FreeBSD 11.2 servers failed to boot with the following error after freebsd-update.  
```
Mounting from zfs:zroot/ROOT/default failed with error 6; retrying for 3 more seconds
```

It was the first time I encountered this type of error.

After struggling for some time, I was able to boot the server by disconnecting an external USB harddrive, which I had prepared as a secondary backup storage.
But since then, I had been wondering what the root cause was.

And today, I've finally found that the USB harddrive had ZFS label information in its UFS partition.  
Did this cause the error? Not sure because I haven't reboot the server yet.  
But anyway, here is what I did to fight the problem.

## Investigating the Root Cause
1. First, I re-connected the USB disk to the server.  
Once it was detected as da4, I ran ``gpart show`` and confirmed there was only a single UFS partition on it.
    ```
    $ gpart show da4
    =>        40  2930277088  da4  GPT  (1.4T)
              40        2008       - free -  (1.0M)
            2048  2930274304    1  freebsd-ufs  (1.4T)
      2930276352         776       - free -  (388K)
    ```

2. Next I checked if there's any ZFS pool available for import.  
I did this because similar problems were reported on the web and they seem to have something to do with a ZFS pool on USB storage.  
Oh wait! Another zroot? Where does it come from?   
    ```
    $ sudo zpool import
       pool: zroot
         id: 10466099340317815455
      state: FAULTED
     status: The pool was last accessed by another system.
     action: The pool cannot be imported due to damaged devices or data.
    	The pool may be active on another system, but can be imported using
    	the '-f' flag.
       see: http://illumos.org/msg/ZFS-8000-EY
     config:
    
    	zroot                     FAULTED  corrupted data
    	  mirror-0                DEGRADED
    	    10037725760255352733  UNAVAIL  cannot open
    	    15874716908755608597  UNAVAIL  corrupted data
    ```

3. The previous command doesn't tell me where the pool is.  
So I disconnect the disk and ran ``zpool import`` again.  
This time it didn't show any pool. Thus the pool must be on the disk (da4).
```
$ sudo zpool import
```

4. Then I examined ZFS label information on the disk with ``zdb -l``.  
First, I ran the command on the whole disk (/dev/da4) but no label was found.
    ```
    $ sudo zdb -l /dev/da4
    ------------------------------------
    LABEL 0
    ------------------------------------
    failed to unpack label 0
    ------------------------------------
    LABEL 1
    ------------------------------------
    failed to unpack label 1
    ------------------------------------
    LABEL 2
    ------------------------------------
    failed to unpack label 2
    ------------------------------------
    LABEL 3
    ------------------------------------
    failed to unpack label 3
    ```

5. Next, I ran it on the UFS partition (/dev/da4p1). Bingo!
    ```
    $ sudo zdb -l /dev/da4p1
    ------------------------------------
    LABEL 0
    ------------------------------------
    failed to unpack label 0
    ------------------------------------
    LABEL 1
    ------------------------------------
    failed to unpack label 1
    ------------------------------------
    LABEL 2
    ------------------------------------
       version: 5000
       name: 'zroot'
       state: 0
       txg: 925
       pool_guid: 10466099340317815455
       hostid: 2883258677
       hostname: 'awabi.example.com'
       top_guid: 3478689283825868568
       guid: 15874716908755608597
       vdev_children: 1
       vdev_tree:
           type: 'mirror'
           id: 0
           guid: 3478689283825868568
           metaslab_array: 34
           metaslab_shift: 33
           ashift: 12
           asize: 1495999709184
           is_log: 0
           create_txg: 4
           children[0]:
               type: 'disk'
               id: 0
               guid: 10037725760255352733
               path: '/dev/gpt/zfs0'
               phys_path: '/dev/gpt/zfs0'
               whole_disk: 1
               create_txg: 4
           children[1]:
               type: 'disk'
               id: 1
               guid: 15874716908755608597
               path: '/dev/gpt/zfs1'
               phys_path: '/dev/gpt/zfs1'
               whole_disk: 1
               create_txg: 4
       features_for_read:
           com.delphix:hole_birth
           com.delphix:embedded_data
    ------------------------------------
    LABEL 3
    ------------------------------------
    failed to unpack label 3
    ```

6. I cleared the label with ``zpool labelclear`` on the partition and confirmed ``zpool import`` didn't list the pool any more.
    ```
    $ sudo zpool labelclear -f /dev/da4p1
    $ sudo zpool import
    ```
**NOTE**: ``zpool labelclear`` destroys the UFS filesystem. Make sure to backup your data first.

## What Made This Weird UFS partition with ZFS label
Okay. I will see if it finally and completely solves the problem on the next reboot.  
By the way, why did this happen?

I found my note on how the USB disk was reused as a secondary backup device on the server.  
It goes like this.
```
# Re-create GPT.
sudo gpart destroy -F da4
sudo gpart create -s gpt da4
# Create a single UFS partition.
sudo gpart add -t freebsd-ufs -a 1m -l usbdisk da4
sudo newfs -S 4096 /dev/da4p1
```

The disk was apparently being used for a ZFS mirrored pool on other system.  
The poolname 'zroot' indicates it was the standard ZFS root disk layout with 3 partitions of type freebsd-boot, freebsd-swap and freebsd-zfs (or 2 partitions of freebsd-boot and freebsd-zfs).  
The pool might be in a ZFS partition at the end of the disk and the partitions might be aligned with 1M boundary.

If my guesses are correct, the end of the UFS partition was on the same place as the ZFS partition which it replaced.  
There's no wonder if one of four ZFS labels were intact after being reused as a UFS partition.

## Lesson Learned
Before reusing a disk, run ``zpool labelclear`` on a whole disk and each partition.
```
zpool labelclear -f da4
zpool labelclear -f da4p1
zpool labelclear -f da4p2
zpool labelclear -f da4p3
```

It took some time but this was really a good learning experience!

