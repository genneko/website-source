---
title: "Expanding a GELI-encrypted ZFS pool"
date: 2019-11-17T19:37:00+09:00
draft: false
tags: [ "storage", "zfs", "geli", "freebsd" ]
toc: false
---
My personal FreeBSD 11.3 server (VPS) was running low on storage space.  
By using the VPS provider's disk expansion option, I could easily grow the virtual disk.  
But then I wondered how to expand the filesystem on it.

In my case, the filesystem is on a GELI-encrypted ZFS storage pool.  
So I had to resize the following entities.

* GPT freebsd-zfs partition
* GELI device on the GPT partition
* ZFS pool comprised of the GELI device

After rehearsing on VirtualBox VMs, I took the following steps to get more free space for the server.

1. First of all, make sure to backup all the important data on the server.  
   I also took a backup of the GELI metadata using the following command and stored it off-site.  
   ```
   # geli backup vtbd0p2 vtbd0p2.eli
   ```

2. Gather disk-related information.  
   The most important here is the Consumer's Mediasize in ``geli list``, which is the current size of the partition where the GELI device resides.  
   (Provider's Mediasize of the partition in ``geom part list`` has the same number, I guess.)  
   Write down this value somewhere so that you can use it when you resize the GELI device after expanding the virtual disk and the partition.
   ```
   # gpart show
   =>       40  419430320  vtbd0  GPT  (200G)
            40       1024      1  freebsd-boot  (512K)
          1064        984         - free -  (492K)
          2048  419426304      2  freebsd-zfs  (200G)
     419428352       2008         - free -  (1.0M)
   
   # geli list
   Geom name: vtbd0p2.eli
   ...
   Providers:
   1. Name: vtbd0p2.eli
      Mediasize: 214746263552 (200G)
      Sectorsize: 4096
      Mode: r1w1e1
   Consumers:
   1. Name: vtbd0p2
      Mediasize: 214746267648 (200G) <--- Note here!
      Sectorsize: 512
      Stripesize: 0
      Stripeoffset: 1048576
      Mode: r1w1e1
   
   # zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   199G   177G  22.1G        -      200G    58%    88%  1.00x  ONLINE  -
   
   # zpool status
     pool: zroot
   ...
   config:
   
           NAME           STATE     READ WRITE CKSUM
           zroot          ONLINE       0     0     0
             vtbd0p2.eli  ONLINE       0     0     0
   ...
   ```

1. Shutdown the server and apply disk expansion option to increase the virtual disk size.

2. Once the disk expansion opearation at the VPS provider is complete, boot the server with FreeBSD 11.3 installer ISO and open a console.

3. Go into "Shell" at the installer's Welcome screen.

4. At this point, ``gpart show`` reports GPT corruption on the virtual disk (vtbd0).  
This is because the GPT secondary metadata is no longer located at the end of the expanded disk.  
   ```
   # gpart show
   =>       40  419430320  vtbd0  GPT  (400G) [CORRUPT]
            40       1024      1  freebsd-boot  (512K)
          1064        984         - free -  (492K)
          2048  419426304      2  freebsd-zfs  (200G)
     419428352       2008         - free -  (1.0M)
   ```
Run the following command to fix this by using the primary metadata at the beginning of the disk.  
   ```
   # gpart recover vtbd0
   # gpart show
   =>       40  838860720  vtbd0  GPT  (400G)
            40       1024      1  freebsd-boot  (512K)
          1064        984         - free -  (492K)
          2048  419426304      2  freebsd-zfs  (200G)
     419428352  419432408         - free -  (200G)
   ```

5. Resize the FreeBSD ZFS partition (vtbd0p2) to make it use all the increased space.
   ```
   # gpart resize -i 2 -a 1m vtbd0
   # gpart show
   =>       40  838860720  vtbd0  GPT  (400G)
            40       1024      1  freebsd-boot  (512K)
          1064        984         - free -  (492K)
          2048  838856704      2  freebsd-zfs  (400G)
     838858752       2008         - free -  (1.0M)
   ```

6. Resize the GELI device on the expanded partition with ``geli resize`` command.  
   Specify the previous partition size with ``-s oldsize`` option to let the command find the GELI metadata, which is no longer at the end of the expanded partition.  
   You can find this value at several places. This time I used vtbd0p2's "Consumer Mediasize" in the output of ``geli list`` I ran before expanding the disk (See step 2).  
   (``geli load`` is used to load the kernel module "geom\_eli.ko".)
   ```
   # geli load
   # geli resize -v -s 214746267648 vtbd0p2
   ```

7. Reboot with the resized partition.
   ```
   # shutdown -r now
   ```

8. Although the underlying partition and the GELI device have been expanded, the ZFS pool size hasn't been changed yet.  
   ```
   # zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   199G   177G  22.1G        -      200G    58%    88%  1.00x  ONLINE  -
   ```
   Use ``zpool online -e`` to expand the ZFS pool on the GELI device.  
   ```
   # zpool online -e zroot vtbd0p2.eli
   # zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   399G   177G   222G        -         -    29%    44%  1.00x  ONLINE  -
   ```

9. That's all!  
The whole process only took an hour where the disk expansion operation at the VPS provider took about 50 minutes.  
   ```
   # gpart show
   =>       40  838860720  vtbd0  GPT  (400G)
            40       1024      1  freebsd-boot  (512K)
          1064        984         - free -  (492K)
          2048  838856704      2  freebsd-zfs  (400G)
     838858752       2008         - free -  (1.0M)
   
   # geli list
   Geom name: vtbd0p2.eli
   ...
   Providers:
   1. Name: vtbd0p2.eli
      Mediasize: 429494628352 (400G)
      Sectorsize: 4096
      Mode: r1w1e1
   Consumers:
   1. Name: vtbd0p2
      Mediasize: 429494632448 (400G)
      Sectorsize: 512
      Stripesize: 0
      Stripeoffset: 1048576
      Mode: r1w1e1
   
   # zpool list
   NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP  HEALTH  ALTROOT
   zroot   399G   174G   225G        -         -    31%    43%  1.00x  ONLINE  -
   
   # zpool status
     pool: zroot
   ...
   config:
   
           NAME           STATE     READ WRITE CKSUM
           zroot          ONLINE       0     0     0
             vtbd0p2.eli  ONLINE       0     0     0
   ...
   ```

## References

* FreeBSD Handbook: zpool Administration  
<https://www.freebsd.org/doc/handbook/zfs-zpool.html>

* FreeBSD Manual: gpart(8)  
<https://www.freebsd.org/cgi/man.cgi?gpart(8)>

* FreeBSD Manual: geli(8)  
<https://www.freebsd.org/cgi/man.cgi?geli(8)>

* FreeBSD Manual: zpool(8)  
<https://www.freebsd.org/cgi/man.cgi?zpool(8)>

* FreeBSD Mastery: Storage Essentials by Michael W. Lucas  
<https://mwl.io/nonfiction/os#fmse>

* FreeBSD Mastery: ZFS by Michael W. Lucas and Allan Jude  
<https://mwl.io/nonfiction/os#fmzfs>

* YAUB (Yet Another Useless blog): Resize a zpool on a FreeBSD geli partition  
<https://stderr.at/blog/freebsd/2015/09/20/freebsd-geli-resize/>

* FreeBSD Forum: [solved]GELI resize doesn't work.  
<https://forums.freebsd.org/threads/solved-geli-resize-doesnt-work.45133/>


