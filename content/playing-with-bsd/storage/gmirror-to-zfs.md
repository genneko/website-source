---
title: "Migrating a live system from GEOM mirror to ZFS mirror"
date: 2018-04-17T15:27:13+09:00
draft: false
tags: [ "storage", "zfs", "geom", "freebsd" ]
toc: false
---
I had been wanting to migrate a FreeBSD system on a GEOM mirror (gmirror) to a ZFS mirror.

After several rehearsals on a VM, I have finally achieved that goal with the following steps.

1. Load ZFS-releated kernel modules and set a tunable to use 4K sector drives.
   ```
   sudo kldload zfs
   sudo sysctl vfs.zfs.min_auto_ashift=12
   ```

2. Remove one (da0) of the two disks (da0, da1) which make up the gmirror (gm0).
   ```
   sudo gmirror remove gm0 da0
   ```

3. Re-create partitions on the disk removed from the gmirror (da0). Label them appropriately.
   ```
   sudo gpart destroy -F da0
   sudo gpart create -s gpt da0
   sudo gpart add -a 4k -t freebsd-boot -s 512k -l zfsboot0 da0
   sudo gpart add -a 1m -t freebsd-zfs -l zfssys0 da0
   sudo gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 da0
   ```

   GEOM mirrored disks usually use MBR partitioning because both gmirror and GPT(another partitioning scheme) store metadata at the end of the disk.

4. Create a ZFS pool (zroot) with a partition (gpt/zfssys0) on da0.
   ```
   sudo zpool create -O compression=lz4 -O atime=off -o altroot=/mnt -m none zroot gpt/zfssys0
   ```

5. Export and re-import the pool and mount it on a temporary location (/mnt).
   ```
   sudo zpool export zroot
   sudo zpool import -o altroot=/mnt zroot
   ```

6. Create datasets in a Boot Environment compliant layout.
   ```
   sudo zfs create -o mountpoint=none zroot/ROOT
   sudo zfs create -o mountpoint=/ zroot/ROOT/default
   sudo zfs create -o mountpoint=/tmp -o exec=on -o setuid=off zroot/tmp
   sudo zfs create -o mountpoint=/usr -o canmount=off zroot/usr
   sudo zfs create -o canmount=off zroot/usr/local
   sudo zfs create -o mountpoint=/home zroot/home
   sudo zfs create -o setuid=off zroot/usr/ports
   sudo zfs create zroot/usr/src
   sudo zfs create zroot/usr/obj
   sudo zfs create -o mountpoint=/var -o canmount=off zroot/var
   sudo zfs create -o exec=off -o setuid=off zroot/var/audit
   sudo zfs create -o exec=off -o setuid=off zroot/var/crash
   sudo zfs create -o exec=off -o setuid=off zroot/var/log
   sudo zfs create -o atime=on zroot/var/mail
   sudo zfs create -o setuid=off zroot/var/tmp
   sudo zfs create -o mountpoint=/data zroot/data
   ```

7. Set bootfs property and fix permissions on temporay directories.
   ```
   sudo zpool set bootfs=zroot/ROOT/default zroot
   sudo chmod 1777 /mnt/tmp
   sudo chmod 1777 /mnt/var/tmp
   ```

8. Copy files from the gmirror to the new ZFS pool.
   ```
   sudo sh -c "find -x / | cpio -pmd /mnt"
   sudo sh -c "find -x /var | cpio -pmd /mnt"
   sudo sh -c "find -x /usr | cpio -pmd /mnt"
   sudo sh -c "find -x /home | cpio -pmd /mnt"
   sudo sh -c "find -x /data | cpio -pmd /mnt
   ```

9. Modify configuration files on the pool.

   [/mnt/boot/loader.conf]
   ```
   # geom_mirror_load="YES"
   kern.geom.label.disk_ident.enable="0"
   kern.geom.label.gptid.enable="0"
   zfs_load="YES"
   ```

   [/mnt/etc/sysctl.conf]
   ```
   vfs.zfs.min_auto_ashift=12
   ```

   [/mnt/etc/rc.conf]
   ```
   zfs_enable="YES"
   ```

   [/mnt/etc/fstab]
   ```
   # comment out all mount entries for gmirror (gm0).
   ```

10. Reboot into ZFS.
    ```
    sudo shutdown -r now
    ```

11. After reboot, destroy the remaining gmirror (gm0) which is no longer used.
    ```
    sudo gmirror load
    sudo gmirror destroy gm0
    ```

12. Re-create partitions on da1 which had remained in the gmirror.
    ```
    sudo gpart destroy -F da1
    sudo gpart create -s gpt da1
    sudo gpart add -a 4k -t freebsd-boot -s 512k -l zfsboot0 da1
    sudo gpart add -a 1m -t freebsd-zfs -l zfssys0 da1
    sudo gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 da1
    ```

13. Add a partition (gpt/zfssys1) on da1 to the ZFS pool (zroot) to form a mirror again. Resilvering starts.

    **NOTE**: To add mirrored disks, use `zpool attach` instead of `zpool add`. The latter expands a pool by adding the specified vdev as another stripe.

    ```
    sudo zpool attach zroot gpt/zfssys0 gpt/zfssys1
    ```

14. When resilvering is done, you've got a brand new ZFS mirror pool!

## References

* FreeBSD Handbook: GEOM: Modular Disk Transformation Framework / RAID1 - Mirroring  
https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/geom-mirror.html

* FreeBSD Handbook: The Z File System (ZFS)  
https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/zfs.html

* FreeBSD Mastery: Storage Essentials by Michael W. Lucas  
https://mwl.io/nonfiction/os#fmse

* FreeBSD Mastery: ZFS by Michael W. Lucas and Allan Jude  
https://mwl.io/nonfiction/os#fmzfs

* FreeBSD Mastery: Advanced ZFS by Michael W. Lucas and Allan Jude  
https://mwl.io/nonfiction/os#fmaz
