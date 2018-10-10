---
title: "Encrypted Temporary Storage with GELI"
date: 2018-09-07T07:13:08Z
draft: false
tags: [ "storage", "zfs", "geom", "geli", "freebsd" ]
toc: true
---
Recently, I wanted an encrypted working directory on a running FreeBSD system. The system was running on a plain (unencrypted) ZFS pool and there's no plan to add disks to it. I needed the working directory only temporarily.

I came up with the following options.

1. Use GELI on a ZFS volume (zvol).
2. Use GELI on a memory disk (md).
3. Use PEFS on a directory.

I excluded PEFS because I had very little experience. I just briefly played with it after hearing about it on an episode of "BSD Now" podcast.

The remaining two have GELI in common, but each one seems to have different characteristics. While memory disk [^1] is relatively small and just for temporary use, zvol is larger and can be used for longer period.

[^1]: I mean swap-backed memory disk here. File-backed memory disk can be an alternative to zvol on a non-ZFS environment.

Here are the steps which I took for both methods.

## GELI on ZFS Volume (zvol)
If you want to use an encrypted directory more than once or you need a large space, zvol might be the best choice [^2].

[^2]: If your system is not using ZFS, you can still use a file-backed (type vnode) memory disk instead of zvol. 

1. Create a ZFS volume.  
You can access the newly created zvol through the device file /dev/zvol/zroot/workvol.
	```
	$ sudo zfs create -V 10g zroot/workvol
	```

2. Encrypt the zvol with GELI.
	```
	$ sudo geli init -s 4096 /dev/zvol/zroot/workvol
	(Enter a passphrase to set)
	```

3. Attach the GELI encrypted zvol.  
This creates the decrypted device node with .eli extension (``/dev/zvol/zroot/workvol.eli``).
	```
	$ sudo geli attach /dev/zvol/zroot/workvol
	(Enter the previously set passphrase)
	```

4. Create a UFS filesystem on the attached GELI volume.
	```
	$ sudo newfs /dev/zvol/zroot/workvol.eli
	```

5. Mount the filesystem.
	```
	$ sudo mount /dev/zvol/zroot/workvol.eli /mnt
	```

6. Do what you want on the mounted filesystem.
	```
	(Do the job under /mnt)
	```

7. Once you are done, unmount and detach the GELI volume.
	```
	$ sudo umount /mnt
	$ sudo geli detach /dev/zvol/zroot/workvol
	```

8. The encrypted zvol can be used later by performing step 3 and 5 again.
	```
	$ sudo geli attach /dev/zvol/zroot/workvol
	(Enter the previously set passphrase)
	$ sudo mount /dev/zvol/zroot/workvol.eli /mnt
	```  
   Or if you no longer need the space, destroy the zvol.
	```
	$ sudo zfs destroy zroot/workvol
	```

## GELI on Memory Disk (md)
If you need a small encrypted storage only once and for a short period, a memory disk encrypted with an onetime key might be enough.

1. Create a swap-backed memory disk.  
If you omit ``-u (unit number or device name)`` option, the newly created device name will be printed.  
In this example, you can access the memory disk through the device /dev/md0.
	```
	$ sudo mdconfig -s 500m
	md0
	```

2. Encrypt and attach the memory disk with a randomly generated onetime key.  
This creates the decrypted device node with .eli extension (``/dev/md0.eli``).
	```
	$ sudo geli onetime -s 4096 /dev/md0
	```

3. Create a UFS filesystem on the attached GELI volume.
	```
	$ sudo newfs /dev/md0.eli
	```

4. Mount the filesystem.
	```
	$ sudo mount /dev/md0.eli /mnt
	```

5. Do what you want on the mounted filesystem.
	```
	(Do the job under /mnt)
	```

6. Once you are done, unmount and detach the GELI volume.
	```
	$ sudo umount /mnt
	$ sudo geli detach /dev/md0
	```

7. Lastly, detach the memory disk.
	```
	$ sudo mdconfig -d -u md0
	```

## References
* FreeBSD Handbook: Memory Disks  
https://www.freebsd.org/doc/handbook/disks-virtual.html

* FreeBSD Handbook: Encrypting Disk Partitions  
https://www.freebsd.org/doc/handbook/disks-encrypting.html

* FreeBSD Handbook: zfs Administration  
https://www.freebsd.org/doc/handbook/zfs-zfs.html

* PEFS - Private Encrypted File System  
http://pefs.io/

* BSD Now: Filesystem-based encryption with PEFS  
https://www.bsdnow.tv/tutorials/pefs


