---
title: "Abusing FreeBSD Bridges to Learn Spanning Tree Protocol"
date: 2018-11-01T17:53:01+09:00
draft: true
tags: [ "network", "bridge", "stp", "freebsd" ]
toc: true
---
Spanning Tree Protocol is a standard protocol for network bridges (layer-two switches) to autonomously find a logical loop-free topology and provide redundancy to the network.

Several variants have been developed since its birth, in which the most common standard is Rapid Spanning Tree Protocol (RSTP). Many managed switches implement the protocol and often enable it by default.

Although it's quite common in the networking world where I'm living in its perimeter, it's been something vague and unfamiliar to me for a long time. Maybe it's because I came from the application layer and gradually went down to lower layers. I can clearly recall the excitement when I sent an email by directly talking to a SMTP server using telnet client for the first time. After all, I'm more interested in the higher layers and I haven't given much attention to the layer one and two.

But recently I noticed that FreeBSD's if_bridge supports RSTP when I was playing with jails and reading related documents. I instantly felt that this is a good opportunity to learn the protocol.

I know there are things called network simulators. Using some of them would save me some time. But as a UNIX hobbyist I want to do it on my own, even if I re-invent the tiny wheel.

This is definitely not a practical usage of FreeBSD [^1] but it's gonna be fun. So I am going to abuse FreeBSD bridges to see how RSTP works!

[^1]: It's also not specific to FreeBSD. The same experiment must be possible with any other operating system which supports STP bridges. I just used my favorite OS.

## Preparation
### Setting up a Single FreeBSD VM
Basically, all I need is a single FreeBSD host. A non-networked physical machine or a vm is best suited because this experiment is inherently dangerous due to possible network loops.

I picked up Vagrant box 'bento/freebsd-11.2' to quickly create a VirtualBox vm running FreeBSD 11.2.  
(Ah, I must confess. My laptop is running Windows 10 and I ran the following commands on cygwin [^2].

[^2]: I'm also testing WSL (Windows Subsystem for Linux). It's handy sometimes but it's not enough to be used as Linux. So I'm still using cygwin as a command-line environment on Windows.
```
$ mkdir -p ~/vagrant/learnstp
$ cd ~/vagrant/learnstp
$ vagrant init
$ vim Vagrantfile
```

I edited the generated Vagrantfile in order to

* set a name of the host and vm.
* add port fowarding rule for a web application visualizing topology.
* enable vm console.
* set a limit on vm's cpu usage.

This is the modified Vagrantfile.
```
Vagrant.configure("2") do |config|
  config.vm.box = "bento/freebsd-11.2"
  config.vm.hostname = "learnstp"
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.name = "learnstp"
    vb.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
  end
end
```

Now fire up the vm and login via ssh.
```
$ vagrant up
$ vagrant ssh
```

You don't have to add anything for building an internal bridged network on the host. Let's create it.

### Building a Simple Network Manually
To grasp the basics of FreeBSD if_bridge STP configurations, I tried first to manually build a simple loop topology with 3 bridges. All the tasks can be done with a single command, ifconfig(8).

<pre style="line-height: 10pt"><code style="font-size: 9pt">
     epair0b +---------+ epair1a
        +----+ bridge1 +----+
        |    +---------+    |
        |                   |
        |                   |
        |                   |
epair0a |                   | epair1b
   +----+----+         +----+----+
   | bridge0 +---------+ bridge2 |
   +---------+         +---------+
         epair2b      epair2a

</code></pre>

This topology requires 3 bridges and 3 links. I used if_bridge(4) for the former and epair(4) for the latter. As I wrote in another post, I usually use ng_bridge(4) in the netgraph(4) framework but it doesn't support STP (it has its own loop-detection mechanism, though). Epair is something like a virtual direct attach cable (DAC), which is a network cable attached with a pluggable tranceiver on either end.

I ran the following commands to create them. Each command prints out a created device name such as bridge0 and epair2a. Note that a single epair provides two pseudo interfaces like epair2a and epair2b. ``ifconfig epair create`` returns only the first one which is suffixed with 'a' but there's also the one with 'b' suffix.
```
$ sudo ifconfig bridge create
bridge0
$ sudo ifconfig bridge create
bridge1
$ sudo ifconfig bridge create
bridge2
$ sudo ifconfig epair create
epair0a
$ sudo ifconfig epair create
epair1a
$ sudo ifconfig epair create
epair2a
```

As I didn't have any bridges and epairs before, now I have bridge0, bridge1, bridge2, epair0a, epair0b, epair1a, epair1b, epair2a and epair2b.
```
$ ifconfig -l
em0 lo0 bridge0 bridge1 bridge2 epair0a epair0b epair1a epair1b epair2a epair2b
```

Next, I connected those bridges with epairs. Because all bridges and epairs are in down state just after their creation, connecting them in loop does not cause packet storm.

To form this topology, I used ``ifconfig addm`` to add member ports (epair pseudo ethernet interfaces) to the bridges.
```
$ sudo ifconfig bridge0 addm epair0a addm epair2b
$ sudo ifconfig bridge1 addm epair1a addm epair0b
$ sudo ifconfig bridge2 addm epair2a addm epair1b
```

By default, Spanning Tree Protocol is disabled on bridge member ports. I used ``ifconfig stp`` to enable it.
```
$ sudo ifconfig bridge0 stp epair0a stp epair2b
$ sudo ifconfig bridge1 stp epair1a stp epair0b
$ sudo ifconfig bridge2 stp epair2a stp epair1b
```
Now bring up bridges and epairs to see how it goes.
```
$ sudo ifconfig bridge0 up
$ sudo ifconfig bridge1 up
$ sudo ifconfig bridge2 up
$ sudo ifconfig epair0a up
$ sudo ifconfig epair0b up
$ sudo ifconfig epair1a up
$ sudo ifconfig epair1b up
$ sudo ifconfig epair2a up
$ sudo ifconfig epair2b up
```

I checked the actual STP topology by running ifconfig for each bridge.
```
$ ifconfig bridge0
bridge0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        ether 02:98:96:7c:39:00
        nd6 options=9<PERFORMNUD,IFDISABLED>
        groups: bridge
        id 02:00:90:00:0b:0b priority 32768 hellotime 2 fwddelay 15
        maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
        root id 02:00:90:00:07:0b priority 32768 ifcost 2000 port 6
        member: epair2b flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 11 priority 128 path cost 2000 proto rstp
                role alternate state discarding
        member: epair0a flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 6 priority 128 path cost 2000 proto rstp
                role root state forwarding

$ ifconfig bridge1
bridge1: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        ether 02:98:96:7c:39:01
        nd6 options=9<PERFORMNUD,IFDISABLED>
        groups: bridge
        id 02:00:90:00:07:0b priority 32768 hellotime 2 fwddelay 15
        maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
        root id 02:00:90:00:07:0b priority 32768 ifcost 0 port 0
        member: epair0b flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 7 priority 128 path cost 2000 proto rstp
                role designated state forwarding
        member: epair1a flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 8 priority 128 path cost 2000 proto rstp
                role designated state forwarding

$ ifconfig bridge2
bridge2: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        ether 02:98:96:7c:39:02
        nd6 options=9<PERFORMNUD,IFDISABLED>
        groups: bridge
        id 02:00:90:00:09:0b priority 32768 hellotime 2 fwddelay 15
        maxage 20 holdcnt 6 proto rstp maxaddr 2000 timeout 1200
        root id 02:00:90:00:07:0b priority 32768 ifcost 2000 port 9
        member: epair1b flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 9 priority 128 path cost 2000 proto rstp
                role root state forwarding
        member: epair2a flags=1c7<LEARNING,DISCOVER,STP,AUTOEDGE,PTP,AUTOPTP>
                ifmaxaddr 0 port 10 priority 128 path cost 2000 proto rstp
                role designated state forwarding
```

After parsing those output, I understood the current topology looks like the following diagram.

<pre style="line-height: 10pt"><code style="font-size: 9pt">
             Root Bridge
     epair0b +---------+ epair1a
        +-(D)| bridge1 |(D)-+
        |    +---------+    |
        |                   |
        |                   |
        |                   |
epair0a(R)   Discard       (R)epair1b
   +---------+   |     +---------+
   | bridge0 |(A)X--(D)| bridge2 |
   +---------+   |     +---------+
         epair2b      epair2a

</code></pre>

Here, bridge1 had the smallest bridge id and was elected as the root bridge. All its member ports became designated ports (D). On bridge0 and bridge2, port closest to the root bridge became root port \(R). On the link between bridge0 and bridge2 (epair2), port on the smaller id bridge became designated port (D) and the other became alternate port (A). The alternate port (A) on bridge0 didn't go into forwarding state and discarded the traffic to prevent loop.

Okay. I could successfully build a Spanning Tree network. But before going any further, I wanted to do some more preparation.

As you can see, it's quite tedious to configure bridges with ifconfig. In addition, It's also hard to see how the physical and logical topologies look like.

To solve those issues, I decided to take some time to write a set of small programs. They are mostly shell scripts to run ifconfig commands in a batch, plus a tiny web application to show bridge topology on a web browser.

### Scripting Bridge Operations
The first program I wrote is a thoughtlessly named ``bridge.sh``. It's just a shell script to run bridge-related operations such as building N-bridge ring or mesh topology, adding a link between bridge A and B, shutting down epairX and showing summary.

With this tiny script, the previously mentioned ring topology can be created by just running a single command.
```
$ sudo ./bridge.sh ring 3
```

With the help of additional scripts written in perl, bridge.sh can also summarize the information nicely. This is far better than ifconfig output for this experiment.  
(I must confess again. Perl is my favorite scripting language.)
```
$ ./bridge.sh show
bridge0 32768.02:00:90:00:0b:0b desig root 32768.02:00:90:00:07:0b cost 2000
  epair0a  proto rstp  id 128.6   cost   2000:       root / forwarding
  epair2b  proto rstp  id 128.11  cost   2000: designated / discarding

bridge1 32768.02:00:90:00:07:0b [root]
  epair0b  proto rstp  id 128.7   cost   2000: designated / forwarding
  epair1a  proto rstp  id 128.8   cost   2000: designated / forwarding

bridge2 32768.02:00:90:00:09:0b desig root 32768.02:00:90:00:07:0b cost 2000
  epair1b  proto rstp  id 128.9   cost   2000:       root / forwarding
  epair2a  proto rstp  id 128.10  cost   2000: designated / discarding
```

I got almost satisfied with those scripts. But the final goal is visualization. So I went on a litte further.

### Visualizing Topology
Visualization has been a buzzword for a while. I've heard a lot about various tools and frameworks to visualize data but I didn't have any idea where to start.

Long story short, I chose [vis.js](https://visjs.org/) to visualize topology on web browser, after trying vanilla HTML5 canvas and [SVG.js](https://svgjs.com/). I also used [Mojolicious](https://mojolicious.org/) to serve HTML/JavaScript and feed topology data in JSON to vis.js running on a web browser.

To start the web application, run the following script. The application starts listening on TCP port 3000.
```
$ ./run-app.sh
```

With the port forwarding configuration in Vagrantfile, I can access the application page from the host PC's web browser with the following URL.
```
http://localhost:3000/index.html
```

Now everything is ready.

## Seeing How RSTP Works

## Quick Start
1. Install the prerequisites.
```
$ sudo pkg install git-lite p5-Mojolicious
```

2. Install the scripts and web application.
```
$ mkdir ~/src
$ cd ~/src
$ git clone https://github.com/genneko/learnstp.git
$ cd learnstp
```

3. Create a topology where four bridges are meshed together.
```
$ sudo ./bridge.sh mesh
```

4. Run the web application.
```
$ ./run-app.sh
```

5. Access the web application from the host OS's web browser.
```
http://localhost:3000/index.html
```

6. Bring down some link to see how the logical topology changes.
```
$ sudo ./bridge.sh linkdown epair1
```

## References
* Vagrant Cloud - Vagrant box bento/freebsd-11.2  
https://app.vagrantup.com/bento/boxes/freebsd-11.2

* FreeBSD Manual: ifconfig(8)  
https://www.freebsd.org/cgi/man.cgi?ifconfig(8)

* FreeBSD Manual: if_bridge(4)  
https://www.freebsd.org/cgi/man.cgi?if_bridge(4)

* FreeBSD Manual: epair(4)  
https://www.freebsd.org/cgi/man.cgi?epair(4)

* FreeBSD Handbook: Advanced Networking / Bridging  
https://www.freebsd.org/doc/en_US.ISO8859-1/books/handbook/network-bridging.html

* Cygwin  
https://cygwin.com/

* vis.js - A dynamic, browser based visualization library  
https://visjs.org/

* SVG.jsa - The lightweight library for manipulating and animating SVG  
https://svgjs.com/

* Mojolicious - Perl real-time web framework  
https://mojolicious.org/

