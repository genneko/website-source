---
title: "Growing a ZFS Mirror Pool"
date: 2019-08-10T18:00:00+09:00
draft: false
tags: [ "storage", "zfs", "freebsd" ]
toc: true
---
I have a tiny home server for my family. It's based on Atom N2800 CPU and runs FreeBSD 11.2 with a two-disk ZFS mirror.

Originally it had two 500GB disks, but now it has a 500GB and a 1TB ones because one of them was replaced due to a failure.

As the Handbook says, the available space of a mirror pool is limited by the size of the smallest disk. So my server can still get only 500GB from the total space of 1.5TB (500GB + 1TB).

It was not a problem because we didn't have much data. But as I got a new FreeBSD laptop and wanted to take its backup on the server, I finally decided to replace the 500GB disk in the mirror with another 1TB one and double the capacity of the mirror.

Here's what I did.

1. Check the current status.  
   I could see ada0(gpt/zfs1) is 1TB and ada1(gpt/zfs0) is 500GB.
   ```
   # camcontrol devlist
   <TOSHIBA MQ01ABD100 AX001U>        at scbus0 target 0 lun 0 (ada0,pass0)
   <TOSHIBA MK5076GSX GS001A>         at scbus1 target 0 lun 0 (ada1,pass1)
   
   # gpart show -l ada0 ada1
   =>        40  1953525088  ada0  GPT  (932G)
             40        1024     1  gptboot1  (512K)
           1064         984        - free -  (492K)
           2048  1953521664     2  zfs1  (932G)
     1953523712        1416        - free -  (708K)
   
   =>       40  976773088  ada1  GPT  (466G)
            40       1024     1  gptboot0  (512K)
          1064        984        - free -  (492K)
          2048  976771072     2  zfs0      (466G)
     976773120          8        - free -  (4.0K)
   
   # zpool status
     pool: zroot
    state: ONLINE
   status: Some supported features are not enabled on the pool. The pool can
   	still be used, but some features are unavailable.
   action: Enable all features using 'zpool upgrade'. Once this is done,
   	the pool may no longer be accessible by software that does not support
   	the features. See zpool-features(7) for details.
     scan: resilvered 341G in 2h24m with 0 errors on Mon Jul 16 14:23:09 2018
   config:
   
   	NAME          STATE     READ WRITE CKSUM
   	zroot         ONLINE       0     0     0
   	  mirror-0    ONLINE       0     0     0
   	    gpt/zfs0  ONLINE       0     0     0
   	    gpt/zfs1  ONLINE       0     0     0
   
   errors: No known data errors
   
   $ zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   464G   386G  78.2G        -         -    39%    83%  1.00x  ONLINE  -
   ```

2. Shutdown the server and replace the 500GB disk with a new 1TB one.

3. Boot the server.

4. See if the new 1TB disk (ada1) is detected.
   ```
   # camcontrol devlist
   PASSWORD: 
   <TOSHIBA MQ01ABD100 AX001U>        at scbus0 target 0 lun 0 (ada0,pass0)
   <TOSHIBA MQ01ABD100 AX101U>        at scbus1 target 0 lun 0 (ada1,pass1)
   ```

5. Partition the new disk, label it and install bootcode on it.
   ```
   # gpart backup ada0 | gpart restore -F ada1
   
   # gpart show -l ada0 ada1
   =>        40  1953525088  ada0  GPT  (932G)
             40        1024     1  gptboot1  (512K)
           1064         984        - free -  (492K)
           2048  1953521664     2  zfs1  (932G)
     1953523712        1416        - free -  (708K)
   
   =>        40  1953525088  ada1  GPT  (932G)
             40        1024     1  (null)  (512K)
           1064         984        - free -  (492K)
           2048  1953521664     2  (null)  (932G)
     1953523712        1416        - free -  (708K)
   
   # gpart modify -i 1 -l gptboot0 ada1
   ada1p1 modified
   
   # gpart modify -i 2 -l zfs0 ada1
   ada1p2 modified
   
   # gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ada1
   partcode written to ada1p1
   bootcode written to ada1
   
   # gpart show -l ada0 ada1
   =>        40  1953525088  ada0  GPT  (932G)
             40        1024     1  gptboot1  (512K)
           1064         984        - free -  (492K)
           2048  1953521664     2  zfs1  (932G)
     1953523712        1416        - free -  (708K)
   
   =>        40  1953525088  ada1  GPT  (932G)
             40        1024     1  gptboot0  (512K)
           1064         984        - free -  (492K)
           2048  1953521664     2  zfs0  (932G)
     1953523712        1416        - free -  (708K)
   ```

6. Replace the missing 500GB disk with the new 1TB one for the ZFS mirror pool.
   ```
   # zpool status
     pool: zroot
    state: DEGRADED
   status: One or more devices could not be opened.  Sufficient replicas exist for
   	the pool to continue functioning in a degraded state.
   action: Attach the missing device and online it using 'zpool online'.
      see: http://illumos.org/msg/ZFS-8000-2Q
     scan: resilvered 341G in 2h24m with 0 errors on Mon Jul 16 14:23:09 2018
   config:
   
   	NAME                     STATE     READ WRITE CKSUM
   	zroot                    DEGRADED     0     0     0
   	  mirror-0               DEGRADED     0     0     0
   	    9104698428201665404  UNAVAIL      0     0     0  was /dev/gpt/zfs0
   	    gpt/zfs1             ONLINE       0     0     0
   
   errors: No known data errors
   
   # zpool replace zroot 9104698428201665404 gpt/zfs0
   Make sure to wait until resilver is done before rebooting.
   
   If you boot from pool 'zroot', you may need to update
   boot code on newly attached disk 'gpt/zfs0'.
   
   Assuming you use GPT partitioning and 'da0' is your new boot disk
   you may use the following command:
   
   	gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 da0
   ```

7. Wait until resilvering completes.
   ```
   # zpool status
     pool: zroot
    state: ONLINE
   status: Some supported features are not enabled on the pool. The pool can
   	still be used, but some features are unavailable.
   action: Enable all features using 'zpool upgrade'. Once this is done,
   	the pool may no longer be accessible by software that does not support
   	the features. See zpool-features(7) for details.
     scan: resilvered 386G in 1h52m with 0 errors on Sat Aug 10 15:53:42 2019
   config:
   
   	NAME          STATE     READ WRITE CKSUM
   	zroot         ONLINE       0     0     0
   	  mirror-0    ONLINE       0     0     0
   	    gpt/zfs0  ONLINE       0     0     0
   	    gpt/zfs1  ONLINE       0     0     0
   
   errors: No known data errors
   ```

8. As you can see, the pool size is not expanded yet.
   ```
   # zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   464G   386G  78.2G        -      464G    39%    83%  1.00x  ONLINE  -
   ```

9. Grow the pool.
   ```
   # zpool online -e zroot gpt/zfs0 gpt/zfs1
   
   $ zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   928G   386G   542G        -         -    19%    41%  1.00x  ONLINE  -
   ```

10. Done!

## References
* FreeBSD Handbook: zpool Administration  
<https://www.freebsd.org/doc/handbook/zfs-zpool.html>

* FreeBSD Manual: zpool(8)  
<https://www.freebsd.org/cgi/man.cgi?zpool(8)>

* FreeBSD Mastery: ZFS by Michael W. Lucas and Allan Jude  
<https://mwl.io/nonfiction/os#fmzfs>


