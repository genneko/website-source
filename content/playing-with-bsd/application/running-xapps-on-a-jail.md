---
title: "Running X Applications on a Jail created with Bastille"
date: 2020-04-11T17:06:00+09:00
draft: false
tags: [ "freebsd", "jail", "ssh", "application", "xorg" ]
toc: true
---
FreeBSD jails are often talked about from a security or system administration perspective.  
Although it's a perfectly valid point of view, jails can also be used for other purposes.

In fact, just recently I benefited from a jail in such a situation.  
It once again convinced me that jails were really awesome and made me write up this short article.

## Assumptions
* The host is a [graphical desktop workstation](/playing-with-bsd/hardware/freebsd-on-thinkpad-t480/) running FreeBSD 12.1/amd64 on ZFS.
* I usually create jails with the procedures described in [this post](/playing-with-bsd/system/learning-notes-on-jails/) - in short, by using the standard tools.  
  But this time, I used [bastille](https://bastillebsd.org/) (a shell-based lightweight jail manager) to quickly setup a jail.  
* Bastille has been installed and configured to be ready for use.  
  PF firewall on the host has been also setup to allow and translate(NAT) traffic for jails.  
  See the official [Getting Started with Bastille guide](https://bastillebsd.org/getting-started/) for more details on how to configure them.
* Bastille's data directory (\$bastille_prefix) is set to /vm/bastille. It's just my personal preference.
* My username on the host is genneko and its user ID (uid) is 500.
* The host is not running sshd (as it's a client machine).
* I use 'sudo' to perform privileged operations on the host while I login to the jail as root.

## The Problem
I wanted to use [Inkscape](https://inkscape.org/) (a vector drawing application), but I couldn't install [graphics/inkscape](https://www.freshports.org/graphics/inkscape) package because it depends on [graphics/ImageMagick6](https://www.freshports.org/graphics/ImageMagick6/) while other existing apps require [ImageMagick7](https://www.freshports.org/graphics/ImageMagick7/). Those ImageMagick versions conflict and cannot be installed on the same system.

## The Solution
As a jail can have its own files and directories and can be regarded as a separate system from the host, I can install packages on a jail without worrying about conflicts with the packages installed on the host.

Although a jail doesn't have a monitor, X applications like Inkscape can display its windows on the X server running on the host, thanks to the client/server nature of the X Window System.

## Configurations
I can think of several combinations of jail types (shared or vnet) and network configurations (address assignment, bridged/routed and etc). But here I pick up just one of them. It's a standard jail with its address on a dedicated loopback interface on the host.

1. Create a 12.1-RELEASE jail. I name it 'xapp' here.
   ```
   $ sudo bastille create xapp 12.1-RELEASE 127.1.1.1
   ```

2. Add the jail's address/hostname to /etc/hosts on both the host and the jail.  
   ```
   $ sudo sh -c 'echo 127.1.1.1 xapp >> /etc/hosts'
   $ sudo sh -c 'echo 127.1.1.1 xapp >> /vm/bastille/jails/xapp/root/etc/hosts'
   ```

3. Start the jail.
   ```
   $ sudo bastille start xapp
   ```

4. Login to the jail.
   ```
   $ sudo bastille console xapp
   ```

5. Configure the jail from inside.

   * Add a user who runs Inkscape.  
     It would be the most convenient to create a user with the same uid as the host's user.
     ```
     # pw useradd -n genneko -u 500 -m
     # passwd genneko
     ```

   * Install xauth, inkscape and its dependencies.  
     Xauth is required for X11 forwarding.
     ```
     # pkg install xauth inkscape
     ```

   * Configure and start SSH server on the jail.  
     ``X11UseLocalhost no`` is required because the 'localhost' in a standard (non-VNET) jail doesn't seem to be the true localhost.  
     Although I'm not sure about this and cannot explain its details, I've confirmed at least that it's not required on a VNET jail which has its own network stack and has a true localhost.
     ```
     # sysrc sshd_enable="YES"
     # echo "X11UseLocalhost no" >> /etc/ssh/sshd_config
     # service sshd start
     ```
   * Exit the jail.
     ```
     # exit
     ```

3. Once back on the host, use ssh to run Inkscape on the jail.  
   The -Y flag enables the Trusted X11 forwarding and the -C enables the compression.
   ```
   $ ssh -CY xapp inkscape
   ```
   Yay, I made it!
   ![Inkscape](/images/running-xapps-on-a-jail/inkscape.png)

4. When I quitted inkscape, I noticed the following warnings on the terminal.  
   ```
   (inkscape:16851): Gdk-WARNING **: 15:46:51.493: shmget failed: error 78 (Function not implemented)
   
   (inkscape:16851): Gtk-WARNING **: 15:49:56.146: Attempting to store changes into `/home/genneko/.local/share/recently-used.xbel', but failed: Failed to create file ?/home/genneko/.local/share/recently-used.xbel.AG2YI0?: No such file or directory
   
   (inkscape:16851): Gtk-WARNING **: 15:49:56.146: Attempting to set the permissions of `/home/genneko/.local/share/recently-used.xbel', but failed: No such file or directory
   ```

   The first warning can be coped with by allowing the jail to access SysV shared memory primitives.  
   Open the jail's configuration with an editor by running either ``sudo bastille edit xapp`` or ``sudo vi /vm/bastille/jails/xapp/jail.conf``.  
   Then add the following line to the 'xapp' section and restart the jail with ``sudo bastille restart xapp``.
   ```
     sysvshm = new;
   ```

   The second and the third warnings can be suppressed by just creating the directory mentioned in the messages on the jail's filesystem.
   ```
   $ mkdir -p /vm/bastille/jails/xapp/root/home/genneko/.local/share
   ```

## Afterwords
I learned it's really easy to install X applications on a jail and use it from the host.  
Other X applications such as xfig, xterm, chromium, firefox[^1] and so on can be also run in the same manner.
[^1]: You may need to specify ``--no-remote`` option to the firefox when you are also running firefox on the host. Without the option, ``ssh -CY xapp firefox`` will create another window of the host's firefox instead of the new one on the jail.

Now I got another reason to love the FreeBSD jails - not the real jails, of course :P

## References
* FreeBSD Manual Pages: jail(8)  
<https://www.freebsd.org/cgi/man.cgi?query=jail(8)>

* Bastille  
https://bastillebsd.org/

* SSH Mastery Second Edition by Michael W. Lucas  
https://mwl.io/nonfiction/tools#ssh

## Revision History
* 2020-04-11: Created
