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

I know there are things called network simulators and they are widely used for education. Using some of them would save me some time. But as a UNIX hobbyist I want to do it on my own, even if I re-invent the tiny wheel.

This is definitely not a practical usage of FreeBSD [^1] but it's gonna be fun. So I am going to abuse FreeBSD bridges to see how RSTP works!

[^1]: It's also not specific to FreeBSD. The same experiment must be possible with any other operating system which supports STP bridges. I just used my favorite OS.

## Preparation
### Setting up a Single FreeBSD VM
Basically, all I need is a single FreeBSD host. A virtual machine is best suited because this experiment is inherently dangerous due to possible network loops.

I picked up Vagrant box 'bento/freebsd-11.2' to quickly create a VirtualBox vm running FreeBSD 11.2.  
(I must confess. My laptop is running Windows 10 and I ran the following commands on cygwin [^2].)

[^2]: I'm also testing WSL (Windows Subsystem for Linux). It's handy sometimes but it's not enough to be used as true UNIX/Linux environment. So I'm still using cygwin as a primary command-line workspace on Windows.
```
$ mkdir -p ~/vagrant/learnstp
$ cd ~/vagrant/learnstp
$ vagrant init
$ vim Vagrantfile
```

I edited the generated Vagrantfile in order to

* set a memorable name for the vm.
* add port fowarding rule for a web application which visualizes topology.
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

Then I fired up the vm and loggged in via ssh.
```
$ vagrant up
$ vagrant ssh
```

### Building a Simple Network Manually
To grasp the basics of FreeBSD bridge's STP configuration, I tried first to manually build a simple loop topology with three bridges. All the tasks can be done using a single command, ifconfig(8).

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

This topology requires three bridges and three links. I used if_bridge(4) for the former and epair(4) for the latter. As I wrote in another article, I usually use ng_bridge(4) in the netgraph(4) framework but it doesn't support STP (it has its own loop-detection mechanism, though). Epair is something like a virtual direct attach cable (DAC), which is a network cable with a pluggable tranceiver on either end.

I ran the following commands to create them. Each command printed out a created device name such as bridge0 and epair2a. Note that a single epair provides two pseudo interfaces (e.g. epair2a and epair2b). ``ifconfig epair create`` returns only the first one which is suffixed with 'a' but there's also the one with 'b' suffix.
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

As I didn't have any bridges and epairs before, now I have bridge0, bridge1, bridge2, epair0a, epair0b, epair1a, epair1b, epair2a and epair2b. Interfaces on a system can be listed by running ifconfig with -l flag.
```
$ ifconfig -l
em0 lo0 bridge0 bridge1 bridge2 epair0a epair0b epair1a epair1b epair2a epair2b
```

Next, I connected those bridges with epairs. I used ``ifconfig addm`` to add member ports (epair pseudo ethernet interfaces) to the bridges.
```
$ sudo ifconfig bridge0 addm epair0a addm epair2b
$ sudo ifconfig bridge1 addm epair1a addm epair0b
$ sudo ifconfig bridge2 addm epair2a addm epair1b
```

By default, Spanning Tree Protocol is disabled on bridge member ports. So I used ``ifconfig stp`` to enable it.
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

I checked STP topology by running ifconfig for each bridge.
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

After struggling with those output, I understood the current topology looks like this.

<pre style="line-height: 10pt"><code style="font-size: 9pt">
             Root Bridge
     epair0b +---------+ epair1a       RSTP Port Roles
        +-(D)| bridge1 |(D)-+             (D) Designated Port
        |    +---------+    |             (R) Root Port
        |                   |             (A) Alternate Port
        |                   |
        |                   |
epair0a(R)   Discard       (R)epair1b
   +---------+   |     +---------+
   | bridge0 |(A)X--(D)| bridge2 |
   +---------+   |     +---------+
         epair2b      epair2a

</code></pre>

Here, bridge1 had the smallest bridge id (priority/id pair) and was elected as the root bridge. All its member ports became designated ports (D). On bridge0 and bridge2, port closest to the root bridge became root port \(R). On the link between bridge0 and bridge2 (epair2), port on the smaller id bridge became designated port (D) and the other became alternate port (A). The alternate port (A) on bridge0 didn't go into forwarding state and discarded the traffic to prevent loop.

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

I got almost satisfied with those scripts. But I went on one step further.

### Visualizing Topology
Visualization has been a buzzword for a while. I've heard a lot about various tools and frameworks to visualize data but I didn't have any idea where to start.

Long story short, I chose [vis.js](https://visjs.org/) to visualize topology on web browser, after trying vanilla HTML5 canvas and [SVG.js](https://svgjs.com/). I also used [Mojolicious](https://mojolicious.org/) to serve HTML/JavaScript and feed topology data in JSON to vis.js running on a web browser.

To start the web application, just run the following script. The application starts listening on TCP port 3000.
```
$ ./run-app.sh
```

With the port forwarding configuration in Vagrantfile, I can access the application page from the host PC's web browser with the following URL.
```
http://localhost:3000/index.html
```

Now everything is in place.

## Seeing How RSTP Works
### Root Bridge Election
For each Spanning Tree network, a single bridge is elected as a root bridge. A root bridge is literally a root of a logical tree of network links, which is calculated by bridges in the network.

As the root bridge operates in the core of a network, it's so important to configure the most appropriate bridge as the root bridge. But how?

In the Spanning Tree network, bridges exchange information and automatically elect a bridge with the lowest bridge id value as a root bridge in the network.

A bridge id is a 8 octets (= bytes) value and is made up of two components - a bridge priority and a bridge MAC address. In the previous example of three bridges, strings like '32768.02:00:90:00:0b:0b' are bridge ids. The first part (e.g. '32768') is the bridge priority and the second part (e.g. '02:00:90:00:0b:0b') is the bridge's MAC address.

<style>
.bl { color: blue; }
.gr { color: green; }
</style>

<pre><code>$ ./bridge.sh show
bridge0 <b class="gr">32768</b>.<b class="bl">02:00:90:00:0b:0b</b> desig root 32768.02:00:90:00:07:0b cost 2000
  epair0a  proto rstp  id 128.6   cost   2000:       root / forwarding
  epair2b  proto rstp  id 128.11  cost   2000: designated / discarding

bridge1 <b class="gr">32768</b>.<b class="bl">02:00:90:00:07:0b</b> [root]
  epair0b  proto rstp  id 128.7   cost   2000: designated / forwarding
  epair1a  proto rstp  id 128.8   cost   2000: designated / forwarding

bridge2 <b class="gr">32768</b>.<b class="bl">02:00:90:00:09:0b</b> desig root 32768.02:00:90:00:07:0b cost 2000
  epair1b  proto rstp  id 128.9   cost   2000:       root / forwarding
  epair2a  proto rstp  id 128.10  cost   2000: designated / discarding
</code></pre>

While MAC address is normally unique and not user-configurable, bridge priority is meant to be configured by administrator. But recommended default of the bridge priority is 32768 and FreeBSD's if_bridge is no exception.

So without explicit configuration, bridge priorities could be the same across all bridges in a network. In that case, a bridge with the smallest MAC address is elected as a root bridge. This is effectively a random selection process.

To avoid this, it is said that network administrators should set bridge priority of the candidate root bridge lower than other ordinary bridges.

Because I didn't do that in the previous example, all bridges had the same priority value 32768 and bridge1, which happened to have the lowest MAC address among three became the root bridge.

Note that MAC addresses are drastically shortened to 2-digit number (it's a hexadecimal actually) on the visualization app for brevity. They only represent relative magnitude among the bridges. Actual MAC address can be seen in a popup which appears by putting your mouse cursor over a bridge.

![3-bridge topology. bridge1 became a root](/images/learning-stp/rstp-3b-r1.jpg)

Now let's try to make bridge0 a root bridge by configuring its bridge priority to a smaller value. Bridge priority can be changed with omnipotent ifconfig command. Here I set bridge0's priority to 4096 [^3].

[^3]: Actually a bridge priority can be only a multiple of 4096 between 0 and 61440.
```
$ sudo ifconfig bridge0 priority 4096
```

Change of bridge priority caused another election process and bridge0 became a new root bridge.

![3-bridge topology. bridge0 became a root](/images/learning-stp/rstp-3b-r0.jpg)

<pre><code>$ ./bridge.sh show
bridge0 <b class="gr">4096</b>.<b class="bl">02:00:90:00:0b:0b</b> [root]
  epair0a  proto rstp  id 128.6   cost   2000: designated / forwarding
  epair2b  proto rstp  id 128.11  cost   2000: designated / forwarding

bridge1 <b class="gr">32768</b>.<b class="bl">02:00:90:00:07:0b</b> desig root 4096.02:00:90:00:0b:0b cost 2000
  epair0b  proto rstp  id 128.7   cost   2000:       root / forwarding
  epair1a  proto rstp  id 128.8   cost   2000: designated / forwarding

bridge2 <b class="gr">32768</b>.<b class="bl">02:00:90:00:09:0b</b> desig root 4096.02:00:90:00:0b:0b cost 2000
  epair1b  proto rstp  id 128.9   cost   2000:  alternate / discarding
  epair2a  proto rstp  id 128.10  cost   2000:       root / forwarding
</code></pre>

It must be undesirable to change priority in production networks but it's okay because this is just an experiment. But if you want to configure a specific bridge to be a root bridge when creating a topology, you can use the -R flag of 'bridge.sh' script.

For example, you can generate the same 3-bridge topology with the first bridge (e.g. bridge0) being a root bridge by running the following command. ``-R 1`` specifies that the first bridge to be a root bridge. The command sets its priority to 4096 while leaving other bridge's priority default 32768.
```
$ sudo ./bridge.sh ring -R 1 3
```

### Determining a Root Port on Each Non-Root Bridge

### Determining Other Port Roles

### Reacting to Topology Changes

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

* SVG.js - The lightweight library for manipulating and animating SVG  
https://svgjs.com/

* Mojolicious - Perl real-time web framework  
https://mojolicious.org/

