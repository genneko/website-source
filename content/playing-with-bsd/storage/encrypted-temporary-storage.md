---
title: "Encrypted Temporary Storage with GELI"
date: 2018-09-07T07:13:08Z
draft: false
tags: [ "storage", "zfs", "geom", "geli", "freebsd" ]
toc: true
---
Recently, I wanted an encrypted working directory on a running FreeBSD system. The system was running on a plain (unencrypted) ZFS pool and there's no plan to add disks to it. I needed the working directory only temporarily.

I came up with the following options.

1. Use GELI on a memory disk (md).
2. Use GELI on a ZFS volume (zvol).
3. Use PEFS on a directory.

I excluded PEFS because I had very little experience. I just briefly played with it after hearing about it on an episode of "BSD Now" podcast.

The remaining two have GELI in common, but each one seems to have different characteristics. While memory disk [^1] is just for temporary use, zvol can be used more permanently.

[^1]: I mean swap-backed memory disk here. File-backed memory disk can be an alternative to zvol on a non-ZFS environment.

Although memory disk was enough for me, I also tried zvol for possible needs in the future.

## GELI on Memory Disk (md)

1. Create a swap-backed memory disk.  
If you specify a size(-s), mdconfig assumes you request swap-backed one (-t swap).  
In this example, you can access the newly created memory disk via the device file /dev/md0.
	```
	$ sudo mdconfig -s 500m
	md0
	```

2. Encrypt the memory disk with GELI.
	```
	$ sudo geli init -s 4096 /dev/md0
	(Enter a passphrase to set)
	```

3. Attach the GELI encrypted memory disk.  
This creates a decrypted device node with .eli extension.
	```
	$ sudo geli attach /dev/md0
	(Enter the previously set passphrase)
	```

4. Create a UFS filesystem on the attached GELI volume.
	```
	$ sudo newfs /dev/md0.eli
	```

5. Mount the filesystem.
	```
	$ sudo mount /dev/md0.eli /mnt
	```

6. Do what you want on the mounted filesystem.
	```
	(Do the job under /mnt)
	```

7. Once you are done, unmount and detach the GELI volume.
	```
	$ sudo umount /mnt
	$ sudo geli detach /dev/md0
	```

8. Lastly, detach the memory disk. `-u 0` specifies "md0" here.
	```
	$ sudo mdconfig -d -u 0
	```

## GELI on ZFS Volume (zvol)

1. Create a ZFS volume.  
You can access the newly created zvol through the device file /dev/zvol/zroot/workvol.
	```
	$ sudo zfs create -V 500m zroot/workvol
	```

2. Encrypt the zvol with GELI.
	```
	$ sudo geli init -s 4096 /dev/zvol/zroot/workvol
	(Enter a passphrase to set)
	```

3. Attach the GELI encrypted zvol.  
This creates a decrypted device node with .eli extension.
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

