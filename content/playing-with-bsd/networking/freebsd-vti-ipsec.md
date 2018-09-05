---
title: "Route-based VPN with FreeBSD-11.1's IPsec VTI"
date: 2017-06-22T15:09:50+09:00
draft: false
tags: [ "network", "vpn", "ipsec", "freebsd" ]
toc: true
---
I have managed to setup route-based IPsec VPN with FreeBSD-11.1 RC3, which had introduced ipsec virtual tunnel interface.
Here is a record of my experiment just for your information.

## Prerequisite
* FreeBSD-11.1-RC3/amd64
* Generic kernel
* No special packages/ports (just added sudo and a few other must-have utilities)

## Network configuration
**NOTE**: The following text shows bsd1 configurations only.
```
                       10.0.0.1      10.0.0.2
192.168.10.0/24 --- [bsd1] ----- /// ----- [bsd2] --- 192.168.20.0/24
172.16.10.0/24                                        172.16.20.0/24
```

## strongSwan setup
### Installation
```
$ sudo pkg install strongswan
```

### /usr/local/etc/ipsec.conf
```
conn route-based
  left = 10.0.0.1
  right = 10.0.0.2
  leftsubnet = 0.0.0.0/0
  rightsubnet = 0.0.0.0/0

  authby = psk
  keyexchange = ikev2
  ike = aes256-sha1-modp1024
  ikelifetime = 28800

  mobike = no
  installpolicy = no
  reqid = 100

  esp = aes256-sha1
  lifetime = 3600

  auto = start
```

### /usr/local/etc/ipsec.secrets
```
10.0.0.2 %any : PSK "xxxxxxxxxxxxxxxx"
```

### /usr/local/etc/strongswan.conf
Just add 'install_routes = no'.
```
charon {
  install_routes = no

  load_modular = yes
  plugins {
    include strongswan.d/charon/*.conf
  }
}

include strongswan.d/*.conf
```

## System setup
### Manually configure IPsec interface and add routes
```
$ sudo ifconfig ipsec0 create reqid 100
$ sudo ifconfig ipsec0 inet tunnel 10.0.0.1 10.0.0.2 up
$ sudo ifconfig ipsec0 inet 169.254.1.1/32 169.254.1.2
$ sudo route add 192.168.20.0/24 169.254.1.2
$ sudo route add 172.16.20.0/24 169.254.1.2
```

### Start strongSwan and do some testing
```
$ sudo service strongswan onestart
...
$ sudo setkey -D
$ sudo setkey -DP
```

### Make them all persistent
At the time of 11.1-RC3, I couldn't find a way to fully setup ipsec interface only with the rc.conf. So I hesitantly use /etc/rc.local.

Maybe /etc/network.subr (clone_up?) will be updated to support it in near future.

#### /etc/rc.conf
```
gateway_enable="YES"
cloned_interfaces="ipsec0"
create_args_ipsec0="reqid 100"
ifconfig_ipsec0="inet 169.254.1.1/32 169.254.1.2"
static_routes="remote1 remote2"
route_remote1="192.168.20.0/24 169.254.1.2"
route_remote2="172.16.20.0/24 169.254.1.2"
strongswan_enable="YES"
```

#### /etc/rc.local
```
ifconfig ipsec0 inet tunnel 10.0.0.1 10.0.0.2
```
