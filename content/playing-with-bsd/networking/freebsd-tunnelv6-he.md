---
title: "Connecting to the IPv6 Internet via tunnel (HE TunnelBroker)"
date: 2018-08-29T15:18:01+09:00
draft: false
tags: [ "network", "ipv6", "freebsd" ]
toc: true
---
I had been playing with IPv6 on various systems in early 2000s. They were mostly NetBSD (1.x) and FreeBSD (4.x) plus Windows XP. My home network had been connected to the IPv6 Internet with a router running NetBSD/hpcmips which was installed on a Windows CE handheld PC.

After a decade and a half, I decided to reconnect my home network to the IPv6 Internet.

Unfortunately, native IPv6 service is still unavailable for me. So I chose Hurricane Electric(HE)'s [TunnelBroker](https://tunnelbroker.net/) service, which I was using 15 years ago.

Another option is to build a tunnel to the VPS which is assigned a single IPv6 address and perform NAT66 there. Although IPv6 NAT sounds somewhat evil, it's interesting enough so I might also give it a try in future and hopefully write up another post.

## Starting Point
My home network is connected to the IPv4 Internet with ASUS RT-AC65U broadband router. The router's WAN interface gets a global IPv4 address via DHCP. The LAN segment is using an ordinary private address block 192.168.1.0/24 and the router is performing NAT.

On the LAN segment, there are two FreeBSD 11.1 boxes, three Windows 10 PCs and several Android devices. One of the FreeBSD boxes is an Atom-based file server using ZFS mirrored pool. The other is a Raspberry Pi Model B+ (RPI-B) which is being used as DHCP/DNS server.

## Goals
My goals are as follows.

1. Connect the home network to the IPv6 Internet.
2. Auto-configure global IPv6 connectivity only on the selected hosts.
3. Make exisiting local DNS servers IPv6 capable.

## Considerations
The first thing to consider is which host to use as the IPv6 router. The existing IPv4 router (ASUS RT-AC65U) has 6in4 tunnel capability so it seems natural to make it IPv4/IPv6 dual-stack gateway.

But there is the one thing about the router which is against the 2nd goal. The router can send RA (Router Advertisement) as an IPv6 gateway but there's no configuration options other than enable/disable it. If I enabled RA on the router, every host on the home network would get LAN's prefix information and auto-configure its IPv6 address and default gateway.

Because I want only the selected hosts to use IPv6 as the goal#2 says, at least in this early stage of my experiment, I have to fine-tune RA contents but the ASUS router doesn't allow it. So I decided to use RPI-B running FreeBSD as the IPv6 router.

For the third goal, there's nothing difficult because the existing DNS servers are using dnsmasq, which is already listening on IPv6 and supports IPv6 address (AAAA) records.

## Building a Tunnel
After creating a new account for the HE TunnelBroker service, I took the following steps to build a 6in4 tunnel.

As I mentioned earlier, the tunnel local endpoint is my RPI-B. Its Ethernet interface is named 'ue0' on FreeBSD 11.1 and assigined a private address 192.168.1.3. The IPv4 default gateway is the ASUS router and its address is 192.168.1.1.

1. Create a tunnel on the TunnelBroker web site. Tunnel details such as addresses and prefixes are shown on the page.  
I use the following parameters in this example.
    ```
    RPI-B LAN IPv4 Address (ue0) : 192.168.1.3 (Behind a NAT box)
    RPI-B LAN IPv6 Address (ue0) : 2001:db8:2:beef::3   <--+
    RPI-B WAN IPv6 Address (gif0): 2001:db8:1:beef::2 <--+ |
                                                         | |
    Tunnel Server IPv4 Address   : 10.10.10.10           | |
    Tunnel Server IPv6 Address   : 2001:db8:1:beef::1    | |
    Tunnel Client IPv6 Address   : 2001:db8:1:beef::2 <--+ |
    Routed /64 Prefix            : 2001:db8:2:beef::/64 <--+
    ```

2. Login to the ASUS router and add the following configurations
    - Add a Port Forwarding (more exactly Protocol Forwarding) rule - Forward Protocol 41(ipv6) from "HE Tunnel Server IPv4 Address" to PRI-B(192.168.1.3) 
    - Disable 'NAT acceleration' on LAN > Switch Control page.
      (I found that IPv6 communication is too slow without this change)


3. Login to the RPI-B and add the following lines to /etc/rc.conf.  
    ```
    pf_enabled="YES"
    pflog_enabled="YES"
    cloned_interfaces="gif0"
    ifconfig_gif0="tunnel 192.168.1.3 10.10.10.10"
    ifconfig_gif0_ipv6="inet6 2001:db8:1:beef::2 2001:db8:1:beef::1 prefixlen 128 mtu 1480"
    ifconfig_ue0_ipv6="inet6 2001:db8:2:beef::XX prefixlen 64"
    ipv6_defaultrouter="2001:db8:beef:1::1"
    ipv6_gateway_enable="YES"
    ```

4. Create or update /etc/pf.conf.  
    ```
    $ sudo vi /etc/pf.conf
    ext_if = "gif0"
    int_if = "ue0"
    localnet = $int_if:network
    icmp6_types = "{ unreach, toobig, timex, paramprob, echoreq, echorep, neighbrsol, neighbradv, routersol, routeradv }"
    tunnel_server = "10.10.10.10"
    
    set skip on lo0
    
    block all
    pass from { self, $localnet }
    pass in inet proto ipv6 from $tunnel_server
    pass inet6 proto icmp6 icmp6-type $icmp6_types
    pass log proto tcp to port ssh
    pass in on $int_if inet proto udp from port = 68 to port = 67
    pass in on $int_if inet6 proto udp from port = 546 to port = 547
    ```

5. Start pf and apply changes.  
    ```
    $ sudo service pf start
    $ sudo service pflog start
    $ sudo service netif restart
    $ sudo service routing restart
    ```

6. Test IPv6 reachability across the tunnel.
    ```
    $ ping6 ff02::1%gif0
    ```

## Setting up RA and DHCPv6
Now the IPv6 tunnel is up, I have to set up rtadvd and dhcpd6 to selectively auto-configure hosts.

1. On the RPI-B, create /etc/rtadvd.conf.  
    ```
    $ sudo vi /etc/rtadvd.conf
    ue0:\
      :rltime#1200:raflags="mo":mtu#1480:\
      :noifprefix:addr="2001:db8:2:beef::":prefixlen#64:\
      :pinfoflags="l":vltime#600:pltime#300:\
      :rdnss="2001:db8:2:beef::3,2001:db8:2:beef::5":
    ```    
   `raflags="mo"` sets Managed Configuration(M) and Other Configuration(O) flags in RA. Those flags notify receiving hosts that they may be able to get address and other information from DHCPv6 server.  
   `noifprefix`, `addr="2001:db8:2:beef::` and `prefixlen#64` explicitly instruct rtadvd to advertise the routed/64 prefix '2001:db8:2:beef::/64'.  
   `pinfoflags="l"` tells rtadvd to set only On-Link(L) flag in prefix information's flags field. By default, Autonomous(A) flag is also set but I remove it because I don't want hosts to autoconfigure their IPv6 address with RA.

2. Install the ISC-DSCP-Server and create /usr/local/etc/dhcpd6.conf.  
Here I configure so that only a single host 'pc1' can get a statically configured IPv6 address (and DNS server addresses).
    ```
    $ sudo pkg update
    $ sudo pkg install isc-dscp43-server
    $ sudo vi /usr/local/etc/dhcpd6.conf
    default-lease-time 600;
    max-lease-time 1200;
    
    host pc1 {
      host-identifier option
        dhcp6.client-id 00:01:00:01:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX;
      fixed-address6 2001:db8:2:beef::8686;
    }
    subnet6 2001:db8:2:beef::/64 {
      option dhcp6.name-servers 2001:db8:2:beef::3, 2001:db8:2:beef::5;
    }
    ```

3. Add the following lines to /etc/rc.conf to enable rtadvd and dhcpd6 on the LAN setgment (ue0).
   ```
    rtadvd_enable="YES"
    rtadvd_interfaces="ue0"
    dhcpd6_enable="YES"
    dhcpd6_ifaces="ue0"
    ```

4. Start rtadvd and dhcpd6.
    ```
    $ sudo service rtadvd start
    $ sudo service isc-dhcpd6 start
    ```

## References
* Hurricane Electric: IPv6 Tunnel Broker  
https://tunnelbroker.net/

* Hurricane Electric's IPv6 Tunnel Broker Forums  
https://forums.he.net/

* FreeBSD Manual Pages: rtadvd.conf(5)  
<https://www.freebsd.org/cgi/man.cgi?rtadvd.conf(5)>

* FreeBSD Manual Pages: pf.conf(5)  
<https://www.freebsd.org/cgi/man.cgi?pf.conf(5)>

* The Book of PF by Peter N. M. Hansteen  
https://nostarch.com/pf3

