---
title: "WireGuard on FreeBSD Quick Look: Testing VPN in Jail Network"
date: 2019-01-20T15:47:34+09:00
lastmod: 2019-01-26T14:25:00+09:00
draft: false
tags: [ "network", "vpn", "wireguard", "freebsd" ]
toc: true
---
[WireGuard](https://www.wireguard.com) is a new VPN application which focuses on simplicity thus security and speed. Although it was initially developed as a Linux kernel feature, now it has a userspace implementation in Go and binary packages are available for FreeBSD.

I used this weekend to have a quick look at it on FreeBSD 12.0.  
This time I focused on site-to-site VPN setup. Maybe I will try remote-access VPN configuration in the near future.

_NOTE: WireGuard is still in early stage of development. Go-implementation (wireguard-go) has no official release yet. Also testing network software on VNET jails might be a bit tricky in itself. This article just shows you what I did to see what it looked like._

2019-01-23: I tested remote-access configuration between FreeBSD and Android. A quick write-up is [here] (/playing-with-bsd/networking/freebsd-wireguard-android).

2019-01-26: Added a [new section] (#remote-access-host-to-site-configuration) on testing remote-access (host-to-site) by a roaming client.

## Prerequisite
* FreeBSD 12.0/amd64
* Generic kernel (finally with VIMAGE enabled)
* Bash as an login shell on the host

## Site-to-Site Configuration
To play quickly with WireGuard, I built the following internal network made up with five VNET jails on a single FreeBSD host.

* r1 (Router forwarding packets between vpnr1 and vpnr2.
* vpnr1 (VPN Router for the site 1)
* vpnr2 (VPN Router for the site 2)
* vpnh1 (Host on the site 1)
* vpnh2 (Host on the site 2)

<pre style="line-height: 10pt"><code style="font-size: 9pt">                                 Site 1

                      vri1_vpnr1      vri1_vpnh1
       [Router(vpnr1)]o ------ (vri1br) ------ o[Host (vpnh1)]
     vi1_vpnr1 o |    192.168.1.1   192.168.1.11
   172.31.1.11 | o wg0
               |  \  192.168.222.1
            (vi1br)\
               |    \
   172.31.1.1  |     \
        vi1_r1 o      \
         [Router(r1)]  | WireGuard tunnel
        vi2_r1 o      /
   172.31.2.1  |     /
               |    /
            (vi2br)/
               |  /
   172.31.2.11 | /   192.168.222.2
               | o wg0
     vi2_vpnr2 o |    192.168.2.1   192.168.2.11
       [Router(vpnr2)]o ------ (vri2br) ------ o[Host (vpnh2)]
                      vri2_vpnr2      vri2_vpnh2

                                 Site 2
</code></pre>

In this configuration,  jail r1 acts as a central router which crudely emulates a public network and is to be used as a monitoring post running tcpdump, while jail vpnr1 and vpnr2 are routers on private sites and remaining two (vpnh1 and vpnh2) are hosts on the private sites.

I planned to run WireGuard on vpnr1 and vpnr2 and build a VPN tunnel between site1 and site2.

For details on jails configuration, please refer to [another post](/playing-with-bsd/system/learning-notes-on-jails/#separate-network-configuration).  
The following sections assume that all five jails are up and running.

### Install WireGuard
Because the jails in the above configuration cannot access network outside of the host system, ``pkg install`` cannot be used to install WireGuard on them. Instead I used ``pkg add`` to install the package files downloaded with ``pkg fetch``.

1. Download package files on the host.  
With -d option, ``pkg fetch`` downloads the specified package plus its dependencies.  
Downloaded files are stored in the host's /var/cache/pkg.
```
sudo pkg fetch -d wireguard
```

2. Make the downloaded package files available to jails.  
Although you can simply copy the files to jails' filesystem, nullfs mount /var/cache/pkg on jails looks much easier.  
The following line in /etc/jail.conf achieves this.  
When you start jails, the host's /var/cache/pkg is mounted on each jail's /mnt directory.  
[/etc/jail.conf]
```
...
mount = "/var/cache/pkg /vm/${name}/mnt nullfs ro 0 0";
...
```

3. Install the package on jails from the host.  
The filepath on the command line is the one viewed from jails not the host.
```
for jail in vpnr1 vpnr2 vpnh2; do
        sudo pkg -j $jail add /mnt/wireguard-0.0.20181218.txz
done
```

### Setup Manually
First I tried to manually setup WireGuard by roughly following [Quick Start](https://www.wireguard.com/quickstart/) guide on the WireGuard website.

1. Create private/public key pairs.  
[vpnr1]
```
mkdir ~/wg
cd ~/wg
wg genkey > private
wg pubkey < private > public
```
[vpnr2]
```
mkdir ~/wg
cd ~/wg
wg genkey > private
wg pubkey < private > public
```

2. Make configuration files.  
[vpnr1:~/wg/wg0.conf]
	```
	[Interface]
	PrivateKey = aGi8VucdQG9h9sWHV2jZT5JmAXZpyadTPJlV4BS1124=
	ListenPort = 51820
	
	[Peer]
	PublicKey = l/bRgqGEAzNtVq9JI3GyYnhFgCRXLNpakPxemH3mrA8=
	AllowedIPs = 192.168.222.2/32, 192.168.2.0/24
	Endpoint = 172.31.2.11:51820
	```
[vpnr2:~/wg/wg0.conf]
	```
	[Interface]
	PrivateKey = 8DlDYe7fBA/vCahHGEBj+6DXs111eFiAIGEnDoKtckA=
	ListenPort = 51820
	
	[Peer]
	PublicKey = uoYkPm6lHnxF5T31lD5LB3OGM8/a4eKyUEYcJm5SXXQ=
	AllowedIPs = 192.168.222.1/32, 192.168.1.0/24
	Endpoint = 172.31.1.11:51820
	```
Interface section defines a local WireGuard interface.  
PrivateKey is a private key string generated by ``wg genkey`` on the local system. It is stored in ~/wg/private.  
ListenPort is a UDP port number on which the local system listens on.  
Peer section defines a remote WireGuard nodes.  
PublicKey is a public key string for a remote system. It is stored in ~/wg/public on the remote system.  
AllowedIPs specifies IP address ranges which is allowed to pass through this WireGuard tunnel.  
Endpoint is an external IP address/UDP port of the remote system which is used to establish VPN connection.

3. Create WireGuard interfaces.
To create WireGuard interface on FreeBSD, you need to run userspace wireguard-go program.  
Once an interface was created, you can assign IP address on the interface, add routes to remote network through the interface and apply WireGuard configuration to the interface.  
[vpnr1]
```
wireguard-go wg0
ifconfig wg0 inet 192.168.222.1 192.168.222.1
route add 192.168.222.2/32 -interface wg0
route add 192.168.2.0/24 -interface wg0
wg setconf wg0 ~/wg/wg0.conf
ifconfig wg0 down up
```
[vpnr2]
```
wireguard-go wg0
ifconfig wg0 inet 192.168.222.2 192.168.222.2
route add 192.168.222.1/32 -interface wg0
route add 192.168.1.0/24 -interface wg0
wg setconf wg0 ~/wg/wg0.conf
ifconfig wg0 down up
```
**NOTE**  
In my environment, wg0 interface didn't work without `ifconfig wg0 down` before `ifconfig wg0 up`.  
By "didn't work", I mean that UDP sockets were not created.  

4. Confirm configurations.  
[vpnr1]
	```
	netstat -rnfinet
	Routing tables
	
	Internet:
	Destination        Gateway            Flags     Netif Expire
	default            172.31.1.1         UGS    vi1_vpnr
	127.0.0.1          link#1             UH          lo0
	172.31.1.0/24      link#2             U      vi1_vpnr
	172.31.1.11        link#2             UHS         lo0
	192.168.1.0/24     link#3             U      vri1_vpn
	192.168.1.1        link#3             UHS         lo0
	192.168.2.0/24     wg0                US          wg0
	192.168.222.1      link#4             UH          wg0
	192.168.222.2/32   wg0                US          wg0
	```
[vpnr1]
	```
	ifconfig wg0
	wg0: flags=8051<UP,POINTOPOINT,RUNNING,MULTICAST> metric 0 mtu 1420
	        options=80000<LINKSTATE>
	        inet 192.168.222.1 --> 192.168.222.1 netmask 0xffffff00
	        inet6 fe80::5c71:f2c9:7123:67ad%wg0 prefixlen 64 scopeid 0x4
	        groups: tun
	        nd6 options=21<PERFORMNUD,AUTO_LINKLOCAL>
	        Opened by PID 6703
	```
[vpnr1]
	```
	wg show
	interface: wg0
	  public key: uoYkPm6lHnxF5T31lD5LB3OGM8/a4eKyUEYcJm5SXXQ=
	  private key: (hidden)
	  listening port: 51820
	
	peer: l/bRgqGEAzNtVq9JI3GyYnhFgCRXLNpakPxemH3mrA8=
	  endpoint: 172.31.2.11:51820
	  allowed ips: 192.168.2.0/24, 192.168.222.2/32
	```

### Test Connectivity and Encryption
Once the configuration was done, I tested site-to-site connectivity by running ping between routers and hosts.  
I was also monitoring packets on the intermediate router (r1) and site2 router (vpnr2) with tcpdump in order to see if the packets are encrypted.

#### Packets outside of the Tunnel
Ping packets from the external address of the router on site 1 (vpnr1: 172.31.1.11) to the router on site 2 (vpnr2: 172.31.2.11) were expected to be unencrypted.  

[vpnr1]
```
ping -c1 -p 504c41494e 172.31.2.11
PATTERN: 0x504c41494e
PING 172.31.2.11 (172.31.2.11): 56 data bytes
64 bytes from 172.31.2.11: icmp_seq=0 ttl=64 time=0.147 ms
...
```

[r1]
```
tcpdump -vln -X -i vi1_r1
09:34:20.976217 IP (tos 0x0, ttl 64, id 8502, offset 0, flags [none], proto ICMP (1), length 84)
    172.31.1.11 > 172.31.2.11: ICMP echo request, id 39437, seq 0, length 64
        0x0000:  4500 0054 2136 0000 4001 fe1e ac1f 010b  E..T!6..@.......
        0x0010:  ac1f 020b 0800 d9e7 9a0d 0000 5c44 409c  ............\D@.
        0x0020:  000e e51e 504c 4149 4e50 4c41 494e 504c  ....PLAINPLAINPL
        0x0030:  4149 4e50 4c41 494e 504c 4149 4e50 4c41  AINPLAINPLAINPLA
        0x0040:  494e 504c 4149 4e50 4c41 494e 504c 4149  INPLAINPLAINPLAI
        0x0050:  4e50 4c41                                NPLA
09:34:20.976276 IP (tos 0x0, ttl 63, id 50381, offset 0, flags [none], proto ICMP (1), length 84)
    172.31.2.11 > 172.31.1.11: ICMP echo reply, id 39437, seq 0, length 64
        0x0000:  4500 0054 c4cd 0000 3f01 5b87 ac1f 020b  E..T....?.[.....
        0x0010:  ac1f 010b 0000 e1e7 9a0d 0000 5c44 409c  ............\D@.
        0x0020:  000e e51e 504c 4149 4e50 4c41 494e 504c  ....PLAINPLAINPL
        0x0030:  4149 4e50 4c41 494e 504c 4149 4e50 4c41  AINPLAINPLAINPLA
        0x0040:  494e 504c 4149 4e50 4c41 494e 504c 4149  INPLAINPLAINPLAI
        0x0050:  4e50 4c41                                NPLA
```

You can see the embedded pattern 'PLAIN' so they are not encrypted.

#### Packets in the Tunnel
Ping packets from the host on site 1 (vpnh1) to the host on site 2 (vpnh2) were to be encapsulated/encrypted on vpnr1 and to be decapsulated/decrypted on vpnr2.

[vpnh1]
```
ping -c1 -p 504c41494e 192.168.2.11
PATTERN: 0x504c41494e
PING 192.168.2.11 (192.168.2.11): 56 data bytes
64 bytes from 192.168.2.11: icmp_seq=0 ttl=62 time=8.150 ms
...
```

[r1]
```
tcpdump -vln -X -i vi1_r1
02:16:56.444934 IP (tos 0x0, ttl 64, id 35847, offset 0, flags [none], proto UDP (17), length 156)
    172.31.1.11.51820 > 172.31.2.11.51820: UDP, length 128
        0x0000:  4500 009c 8c07 0000 4011 92f5 ac1f 010b  E.......@.......
        0x0010:  ac1f 020b ca6c ca6c 0088 d7c4 0400 0000  .....l.l........
        0x0020:  bbe8 7f40 0200 0000 0000 0000 6849 62b9  ...@........hIb.
        0x0030:  3d51 ffdb 158a b426 f622 6599 be69 9e82  =Q.....&."e..i..
        0x0040:  981a 1d2c 15c7 c81f 61ed 27f1 86f3 2048  ...,....a.'....H
        0x0050:  ef82 0570 80cb 3444 3c41 add9 e40c c963  ...p..4D<A.....c
        0x0060:  ae2b faac ef78 7757 2d3c 44b1 3ef5 871f  .+...xwW-<D.>...
        0x0070:  bc06 5d10 b727 0ce1 4e33 8c01 47b0 da66  ..]..'..N3..G..f
        0x0080:  79c7 f861 8266 2bfb 3b4f 9151 c192 ebc6  y..a.f+.;O.Q....
        0x0090:  ed64 a9e1 a5e2 5fd8 51f1 bad2            .d...._.Q...
02:16:56.449331 IP (tos 0x0, ttl 63, id 23891, offset 0, flags [none], proto UDP (17), length 156)
    172.31.2.11.51820 > 172.31.1.11.51820: UDP, length 128
        0x0000:  4500 009c 5d53 0000 3f11 c2a9 ac1f 020b  E...]S..?.......
        0x0010:  ac1f 010b ca6c ca6c 0088 d217 0400 0000  .....l.l........
        0x0020:  d272 6289 0100 0000 0000 0000 28bb 220e  .rb.........(.".
        0x0030:  b8ab b371 db34 9421 bf6a b713 91e9 d15e  ...q.4.!.j.....^
        0x0040:  fdaf 721e bc41 b1be c302 9914 db9f 59c2  ..r..A........Y.
        0x0050:  c0a8 6428 b103 06b1 7cad 897c 8359 6f91  ..d(....|..|.Yo.
        0x0060:  95aa 2481 c80b 1bd3 3fb1 6186 f123 036f  ..$.....?.a..#.o
        0x0070:  f779 3ac9 10f9 df02 75fa e89e ebe5 9bd6  .y:.....u.......
        0x0080:  506f 4b5e 5228 db0e a4ca bd9e e131 c264  PoK^R(.......1.d
        0x0090:  8f1c 0cd5 83f1 d423 04a2 b99c            .......#....
```

On the intermediate router (r1), the Ping packets were encapsulated in those UDP packets sent between port 51820 of vpnr1 and vpnr2. They were WireGuard tunnel packets and their contents were apparently encrypted.

[vpnr2]
```
tcpdump -vln -X -i vi2_vpnr2
02:16:56.444955 IP (tos 0x0, ttl 63, id 35847, offset 0, flags [none], proto UDP (17), length 156)
    172.31.1.11.51820 > 172.31.2.11.51820: UDP, length 128
        0x0000:  4500 009c 8c07 0000 3f11 93f5 ac1f 010b  E.......?.......
        0x0010:  ac1f 020b ca6c ca6c 0088 d7c4 0400 0000  .....l.l........
        0x0020:  bbe8 7f40 0200 0000 0000 0000 6849 62b9  ...@........hIb.
        0x0030:  3d51 ffdb 158a b426 f622 6599 be69 9e82  =Q.....&."e..i..
        0x0040:  981a 1d2c 15c7 c81f 61ed 27f1 86f3 2048  ...,....a.'....H
        0x0050:  ef82 0570 80cb 3444 3c41 add9 e40c c963  ...p..4D<A.....c
        0x0060:  ae2b faac ef78 7757 2d3c 44b1 3ef5 871f  .+...xwW-<D.>...
        0x0070:  bc06 5d10 b727 0ce1 4e33 8c01 47b0 da66  ..]..'..N3..G..f
        0x0080:  79c7 f861 8266 2bfb 3b4f 9151 c192 ebc6  y..a.f+.;O.Q....
        0x0090:  ed64 a9e1 a5e2 5fd8 51f1 bad2            .d...._.Q...
02:16:56.449308 IP (tos 0x0, ttl 64, id 23891, offset 0, flags [none], proto UDP (17), length 156)
    172.31.2.11.51820 > 172.31.1.11.51820: UDP, length 128
        0x0000:  4500 009c 5d53 0000 4011 c1a9 ac1f 020b  E...]S..@.......
        0x0010:  ac1f 010b ca6c ca6c 0088 d217 0400 0000  .....l.l........
        0x0020:  d272 6289 0100 0000 0000 0000 28bb 220e  .rb.........(.".
        0x0030:  b8ab b371 db34 9421 bf6a b713 91e9 d15e  ...q.4.!.j.....^
        0x0040:  fdaf 721e bc41 b1be c302 9914 db9f 59c2  ..r..A........Y.
        0x0050:  c0a8 6428 b103 06b1 7cad 897c 8359 6f91  ..d(....|..|.Yo.
        0x0060:  95aa 2481 c80b 1bd3 3fb1 6186 f123 036f  ..$.....?.a..#.o
        0x0070:  f779 3ac9 10f9 df02 75fa e89e ebe5 9bd6  .y:.....u.......
        0x0080:  506f 4b5e 5228 db0e a4ca bd9e e131 c264  PoK^R(.......1.d
        0x0090:  8f1c 0cd5 83f1 d423 04a2 b99c            .......#....

tcpdump -vln -X -i vri2_vpnr2
02:16:56.448996 IP (tos 0x0, ttl 62, id 4830, offset 0, flags [none], proto ICMP (1), length 84)
    192.168.1.11 > 192.168.2.11: ICMP echo request, id 12830, seq 0, length 64
        0x0000:  4500 0054 12de 0000 3e01 e564 c0a8 010b  E..T....>..d....
        0x0010:  c0a8 020b 0800 c426 321e 0000 5c43 da18  .......&2...\C..
        0x0020:  0006 c95b 504c 4149 4e50 4c41 494e 504c  ...[PLAINPLAINPL
        0x0030:  4149 4e50 4c41 494e 504c 4149 4e50 4c41  AINPLAINPLAINPLA
        0x0040:  494e 504c 4149 4e50 4c41 494e 504c 4149  INPLAINPLAINPLAI
        0x0050:  4e50 4c41                                NPLA
02:16:56.449059 IP (tos 0x0, ttl 64, id 2573, offset 0, flags [none], proto ICMP (1), length 84)
    192.168.2.11 > 192.168.1.11: ICMP echo reply, id 12830, seq 0, length 64
        0x0000:  4500 0054 0a0d 0000 4001 ec35 c0a8 020b  E..T....@..5....
        0x0010:  c0a8 010b 0000 cc26 321e 0000 5c43 da18  .......&2...\C..
        0x0020:  0006 c95b 504c 4149 4e50 4c41 494e 504c  ...[PLAINPLAINPL
        0x0030:  4149 4e50 4c41 494e 504c 4149 4e50 4c41  AINPLAINPLAINPLA
        0x0040:  494e 504c 4149 4e50 4c41 494e 504c 4149  INPLAINPLAINPLAI
        0x0050:  4e50 4c41                                NPLA
```

On the router on site 2 (vpnr2), the Ping packets were encapsulated/encrypted on the external interface (vi2_vpnr2) but not so on the internal interface (vri2_vpnr2).

### Configure WireGuard Service with rc.d
Now I know how to configure WireGuard on FreeBSD systems.  
But to use it in the real world, I had to script the procedures in some way for automatic startup/shutdown of the tunnel.

Then I realized that there's already an rc.d script /usr/local/etc/rc.d/wireguard which came with the wireguard package.

The script uses wg-quick bash script to setup/shutdown tunnels. Its configuration is simple as follows. I only added Address parameter which specifies the IP address set on the WireGuard interface.

wg-quick script reads the configutation and automatically creates a WireGuard interface, assign IP address (Address) on the interface and adds routes to remote network (AllowedIPs) through the interface.

vpnr1 [/usr/local/etc/wireguard/wg0.conf]
```
[Interface]
Address = 192.168.222.1/32
PrivateKey = aGi8VucdQG9h9sWHV2jZT5JmAXZpyadTPJlV4BS1124=
ListenPort = 51820

[Peer]
PublicKey = l/bRgqGEAzNtVq9JI3GyYnhFgCRXLNpakPxemH3mrA8=
AllowedIPs = 192.168.222.2/32, 192.168.2.0/24
Endpoint = 172.31.2.11:51820
```

vpnr2 [/usr/local/etc/wireguard/wg0.conf]
```
[Interface]
Address = 192.168.222.2/32
PrivateKey = 8DlDYe7fBA/vCahHGEBj+6DXs111eFiAIGEnDoKtckA=
ListenPort = 51820

[Peer]
PublicKey = uoYkPm6lHnxF5T31lD5LB3OGM8/a4eKyUEYcJm5SXXQ=
AllowedIPs = 192.168.222.1/32, 192.168.1.0/24
Endpoint = 172.31.1.11:51820
```

To enable and start WireGuard service, run the following commands on both vpnr1 and vpnr2.
```
sysrc wireguard_enable=YES
sysrc wireguard_interfaces="wg0"
service wireguard start
```

## Remote Access (Host-to-Site) Configuration
A few days later I also tried a remote access VPN configuration where the host vpnh2 connected to the router vpnr1 and its inner network (192.168.1.0/24).

The router vpnr2 ran WireGuard in the previous site-to-site example, but in the modified configuration it became an ordinary router/NAT box.

<pre style="line-height: 10pt"><code style="font-size: 9pt">                                 Site 1

                      vri1_vpnr1      vri1_vpnh1
       [Router(vpnr1)]o ------ (vri1br) ------ o[Host (vpnh1)]
     vi1_vpnr1 o |    192.168.1.1   192.168.1.11
   172.31.1.11 | o wg0
               |  \  192.168.222.1
            (vi1br)\
               |    \
   172.31.1.1  |     \
        vi1_r1 o      \
         [Router(r1)]  WireGuard
        vi2_r1 o         tunnel
   172.31.2.1  |                \
               |                 \
            (vi2br)               \
               |                   \                     192.168.222.211
   172.31.2.11 |                    \----------------o wg0
               |                                     |
     vi2_vpnr2 o      192.168.2.1   192.168.2.11     |
       [Router(vpnr2)]o ------ (vri2br) ------ o[Host (vpnh2)]
                      vri2_vpnr2      vri2_vpnh2

                                 Site 2
</code></pre>

### Change Settings
Here is a summary of changes which I made to the site-to-site configuration.

1. Reconfigure vpnr2 and make it a normal NAT router.  
[vpnr2:/etc/pf.conf]
```
XIF = "vi2_vpnr2"
PRIVATENET = "192.168.2.0/24"
nat on $XIF inet from $PRIVATENET to any -> ($XIF)
```
[vpnr2]
```
service wireguard stop
sysrc wireguard_enable="NO"
sudo sysrc pf_enable="YES"
sudo service pf start
```

2. Configure WireGuard on vpnh2.  
[vpnh2]
```
cd /usr/local/etc/wireguard
wg genkey > private
wg pubkey < private > public
vi wg0.conf
```
[vpnh2:/usr/local/etc/wireguard/wg0.conf]
	```
	[Interface]
	Address = 192.168.222.211/32
	PrivateKey = content of <private>
	
	[Peer]
	PublicKey = uoYkPm6lHnxF5T31lD5LB3OGM8/a4eKyUEYcJm5SXXQ=
	AllowedIPs = 192.168.222.1/32, 192.168.1.0/24
	Endpoint = 172.31.1.11:51820
	```
[vpnh2]
```
sysrc wireguard_enable="YES"
sysrc wireguard_interfaces="wg0"
service wireguard start
```

3. Reconfigure vpnr1 to accept connection from vpnh2 instead of vpnr2.  
[vpnr1:/usr/local/etc/wireguard/wg0.conf]
	```
	[Interface]
	Address = 192.168.222.1/32
	PrivateKey = aGi8VucdQG9h9sWHV2jZT5JmAXZpyadTPJlV4BS1124=
	ListenPort = 51820
	
	[Peer]
	PublicKey = content of vpnh2's <public>
	AllowedIPs = 192.168.222.211/32
	```
[vpnr1]
```
service wireguard stop
service wireguard start
```

### Test and Monitor
Let's test connectivity with ping from vpnh2 to vpnh1.

1. Start tcpdump on the intermediate router r1 to monitor WireGuard packets.  
[r1]  
```
tcpdump -ln -i vi1_r1
```

2. On the WireGuard client host vpnh2, start ping to the host vpnh1 (192.168.1.11) which is on the private network behind the remote VPN router vpnr1.  
[vpnh2]
```
ping 192.168.1.11
PING 192.168.1.11 (192.168.1.11): 56 data bytes
64 bytes from 192.168.1.11: icmp_seq=0 ttl=63 time=1.669 ms
64 bytes from 192.168.1.11: icmp_seq=1 ttl=63 time=0.903 ms
...
```

3. Check r1's console.  
You can see WireGuard's UDP packets between vpnr1 and vpnr2.  
[r1]
```
08:08:42.810690 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:08:42.811823 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
08:08:43.838714 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:08:43.840446 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
...
```
Why vnpr2? Isn't it vpnh2?  
It's because vpnh2's address (192.168.2.11) is tranlated to the external address of vpnr2 (172.31.2.11) by vpnr2's NAT function.  
This can be confirmed by running tcpdump on vpnr2's external and internal interfaces.

4. Monitor WireGuard packets on NAT box vpnr2.  
On the internal vri2_vpnr2 interface, WireGuard packets have vpnh2's address 192.168.2.11 for its source or destination.  
But on the external vi2_vpnr2 interface, the vpnh2's address is tranlated to vi2_vpnr2 interface's adddress.  
[vpnr2]
```
tcpdump -ln -i vri2_vpnr2
08:13:53.948608 IP 192.168.2.11.51820 > 172.31.1.11.51820: UDP, length 128
08:13:53.949736 IP 172.31.1.11.51820 > 192.168.2.11.51820: UDP, length 128
08:13:55.011758 IP 192.168.2.11.51820 > 172.31.1.11.51820: UDP, length 128
08:13:55.012736 IP 172.31.1.11.51820 > 192.168.2.11.51820: UDP, length 128
^C
tcpdump -ln -i vi2_vpnr2
08:14:03.258349 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:14:03.258977 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
08:14:04.331344 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:14:04.333282 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
^C
```

5. You can also see the remote VPN router vpnr1 is decrypting/decapsulating incoming packets and vise versa to outgoing packets.  
[vpnr1]
```
tcpdump -ln -i vi1_vpnr1
08:16:35.061792 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:16:35.062845 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
08:16:36.079824 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:16:36.080811 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
^C
tcpdump -ln -i vri1_vpnr1
08:16:43.379386 IP 192.168.222.211 > 192.168.1.11: ICMP echo request, id 64096, seq 522, length 64
08:16:43.379533 IP 192.168.1.11 > 192.168.222.211: ICMP echo reply, id 64096, seq 522, length 64
08:16:44.419530 IP 192.168.222.211 > 192.168.1.11: ICMP echo request, id 64096, seq 523, length 64
08:16:44.419601 IP 192.168.1.11 > 192.168.222.211: ICMP echo reply, id 64096, seq 523, length 64
^C
```

### What if the Host Moves
Now that basic connectivity was confirmed, next I went one step further to see what happened if the client vpnh2 moved to other subnet.

1. To quickly let vpnh2 go out and back, I made the following small shell scripts on the host.  
[host:goout.sh]
```
#!/bin/sh
ngctl rmhook vri2_vpnh2: ether
ngctl connect vi2br: vri2_vpnh2: link2 ether
jexec vpnh2 ifconfig vri2_vpnh2 inet 172.31.2.111/24
jexec vpnh2 route add default 172.31.2.1
```
[host:goback.sh]
```
#!/bin/sh
ngctl rmhook vri2_vpnh2: ether
ngctl connect vri2br: vri2_vpnh2: link2 ether
jexec vpnh2 ifconfig vri2_vpnh2 inet 192.168.2.11/24
jexec vpnh2 route add default 192.168.2.1
```

2. Assume ping from vpnh2 to vpnh1 is still ongoing.  
[vpnh2]
```
...
64 bytes from 192.168.1.11: icmp_seq=1330 ttl=63 time=1.872 ms
```
[r1]
```
...
08:30:43.318780 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:30:43.319744 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
```

3. Move vpnh2 to 172.31.2.0/24 subnet (outside of vpnr2). Its address was changed from 192.168.2.11 to 172.31.2.111 and its packets no longer went through NAT.  
[host]
```
sudo sh ./goout.sh
```

4. See what happens.  
Source IP address of WireGuard packets were changed from 172.31.2.11 to 172.31.2.11 while vpnh2 was receiving ping responses continuously.  
[vpnh2]
```
64 bytes from 192.168.1.11: icmp_seq=1331 ttl=63 time=1.908 ms
64 bytes from 192.168.1.11: icmp_seq=1332 ttl=63 time=0.731 ms
```
[r1]
```
08:30:44.349088 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:30:44.349997 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
08:30:45.388243 IP 172.31.2.111.51820 > 172.31.1.11.51820: UDP, length 128
08:30:45.388659 IP 172.31.1.11.51820 > 172.31.2.111.51820: UDP, length 128
```

5. Move vpnh2 back to the original 192.168.2.0/24 subnet (inside of vpnr2). Its address was changed back from 172.31.2.111 to 192.168.2.11 and its packets went through NAT again.  
[host]
```
sudo sh ./goback.sh
```

6. See what happens once more.  
Source of WireGuard packets were changed back to 172.31.2.11 but ping continued to be received responses on vpnh2.  
[vpnh2]
```
64 bytes from 192.168.1.11: icmp_seq=1333 ttl=63 time=1.281 ms
64 bytes from 192.168.1.11: icmp_seq=1334 ttl=63 time=1.772 ms
...
```
[r1]
```
08:30:46.419636 IP 172.31.2.111.51820 > 172.31.1.11.51820: UDP, length 128
08:30:46.420342 IP 172.31.1.11.51820 > 172.31.2.111.51820: UDP, length 128
08:30:47.449488 IP 172.31.2.11.60574 > 172.31.1.11.51820: UDP, length 128
08:30:47.450383 IP 172.31.1.11.51820 > 172.31.2.11.60574: UDP, length 128
...
```

## Caveats

### On VNET Jails, wgX cannot be destroyed
This is true for both manual and rc.d setup but not the case in non-Jail environment.  
Because of this, ``service wireguard stop`` in a jail gets stuck when it waits for the interface to be destroyed.

Manually running ``ifconfig wg0 destroy`` fails with the following message.
```
ifconfig wg0 destroy
ifconfig: SIOCIFDESTROY: Invalid argument
```

I found that renaming the interface from wgX to tunX lets you destroy it but this operation sometimes caused reboot on my system.
```
ifconfig wg0 name tun0
ifconfig tun0 destroy
```

wireguard-go initially creates a tun interface then renames it to the one specified on command-line. I could workaround this can't-destroy problem by using tunX (e.g. tun1) as a WireGuard interface name from the beginning, but specifying tun0 failed with the following message.
```
ERROR: (tun0) 2019/01/20 05:51:29 Failed to create TUN device: failed to rename tun0 to tun0: file exists
```
I think this can be fixed by adding a simple check to wireguard-go's CreateTUN() function in tun/tun_freebsd.go.

For the fact that wg0 cannot be destroyed in jails, I'm not sure what the root cause is. But I noticed some weirdness in tun interface's unit number assignment.

When I created tun0 on one jail, I couldn't create tun0 on other jails nor the host.
```
vpnr1# ifconfig tun create
tun0
---
vpnr2# ifconfig tun0 create
ifconfig: SIOCIFCREATE2: File exists
vpnr2# ifconfig tun create
tun1
---
host# ifconfig tun0 create
ifconfig: SIOCIFCREATE2: File exists
host# ifconfig tun1 create
ifconfig: SIOCIFCREATE2: File exists
host# ifconfig tun create
tun2
```

I wonder if it means that if_tun's unit number is assigned sequentially across all jails and host?  
As far as I know, other interface types such as lo and gif seems to have separate unit number namespace for each jail thus I can create those types of interfaces with the same name on multiple jails and host.

### rc.d script leaves two processes after shutdown
This is not specific to jails.

When using /usr/local/etc/rc.d/wireguard rc.d script, two processes are left after running ``service wireguard stop``. They looks like processes representing monitor_daemon() in wg-quick script.
```
ps axl
UID  PID PPID CPU PRI NI   VSZ  RSS MWCHAN STAT TT     TIME COMMAND
...
  0 6805    1   0  52  0 13004 3944 wait   IJ    1  0:00.00 /usr/local/bin/bash
  0 6806 6805   0  20  0 10956 2308 sbwait IJ    1  0:00.00 route -n monitor
...
```

I guess this can be fixed by adding code for shutting down the processes by their PIDs to wg-quick but I'm not sure what is the best way.

## References
* WireGuard  
<https://www.wireguard.com/>

* WireGuard for FreeBSD  
<https://lists.freebsd.org/pipermail/freebsd-ports/2018-May/113434.html>

## Revision History
* 2019-01-20: Created
* 2019-01-26: Added "Remote Access (Host-to-Site) Configuration"
