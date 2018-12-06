---
title: "Using FreeBSD's Bootonly Installer Behind a Proxy"
date: 2018-12-06T21:58:00+09:00
draft: false
tags: [ "freebsd", "installation" ]
toc: true
---
I've been so busy for the last month that I almost forgot about FreeBSD 12.0 which I had been looking forward to. Now it's just around the corner!  
Although it's quite late, I tried to install 12.0-RC3 on a host behind a HTTP proxy and found that using a bootonly installer in this environment was a bit tricky. The following are the steps I took.

1. Boot the host with a bootonly installer.

2. Go into Shell at the Welcome dialog.

3. Select an appropriate keymap for my keyboard.
```
kbdcontrol -l jp
```

4. Set the http_proxy environment variable to let installer fetch distribution sets (tarballs) via proxy.
```
export http_proxy=proxyhost:3128
```

5. Run the standard installer program 'bsdinstall' and proceed to disk partitioning screen.
```
bsdinstall
```

6. Just before hitting OK at the "Last chance!" confirmation dialog, press [Alt] + [F4] to open a console and set up IP and DNS configurations. 
If a DHCP server is available, the easiest way is to run the following command.
```
dhclient em0
```
If not, manually configure IP address with ifconfig and add nameserver lines to /tmp/bsdinstall_etc/resolv.conf (symlinked to /etc/resolv.conf). 
It's might be something like:
```
ifconfig em0 inet 10.0.2.15/24
route add default 10.0.2.2
echo nameserver 192.168.10.1 > /tmp/bsdinstall_etc/resolv.conf
```

7. Go back to the installer screen with [Alt] + [F1] and go on.

8. Before exiting the installer, I usually ran the following commands in chrooted shell to rearrange ZFS dataset to use true /home instead of /usr/home symlinked to /home.
```
zfs rename zroot/usr/home zroot/home
zfs set mountpoint=/home zroot/home
rm /home
```
