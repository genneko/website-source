---
title: "WireGuard on FreeBSD Quick Look Part 2: Android Remote Access"
date: 2019-01-23T01:22:00+09:00
draft: false
tags: [ "network", "vpn", "wireguard", "freebsd", "android" ]
toc: true
---
After playing briefly with WireGuard (See [previous post](/playing-with-bsd/networking/freebsd-wireguard-quicklook)) on FreeBSD VNET Jails, today I tried to test it on a FreeBSD host and an Android device which are connected to the Internet.

## Network Configuration
* FreeBSD - WireGuard Server.  
I setup a FreeBSD 11.2 droplet (VPS) on DigitalOcean for this experiment. Using wireguard and wireguard-go packages.  

* Android - WireGuard Client.  
Android 8.0 Phone with WireGuard App (Beta) and ConnectBot installed.  
Roaming between home WiFi and 4G network.

<pre style="line-height: 10pt"><code style="font-size: 9pt">                  Server [FreeBSD]
                             o vtnet0
                             | wg.example.com (xxx.xxx.xxx.xxx)
                             |
                         ///////////
                      /// Internet ///
                         ///////////-------+
                             |              \
                             |               \
             zzz.zzz.zzz.zzz o                \
        Performing NAT [Home Router]           \
                             o                  \
                             | WiFi              \ 4G
                             o                    o yyy.yyy.yyy.yyy
                  Client [Android]<--Roaming-->[Android]
</code></pre>

## Install WireGuard
### FreeBSD
I also installed libqrencode package to pass configuration to Android.
```
sudo pkg install wireguard libqrencode
```

### Android
Install WireGuard App (Beta) from Google Play.  
<https://play.google.com/store/apps/details?id=com.wireguard.android>

## Configure WireGuard
### FreeBSD
1. Generate private/public key pairs for FreeBSD and Android.
	```
	sudo su
	cd /usr/local/etc/wireguard
	wg genkey > freebsd.private
	wg pubkey < freebsd.private > freebsd.public
	wg genkey > android.private
	wg pubkey < android.private > android.public
	```

2. Create a configuration file for the server (FreeBSD).
	```
	vi wg0.conf
	```

	[wg0.conf]
	```
	[Interface]
	Address = 192.168.222.1/32
	PrivateKey = <content of freebsd.private>
	ListenPort = 51820
	
	[Peer]
	PublicKey = <content of android.public>
	AllowedIPs = 192.168.222.2/32
	```

3. Create a configuration file for the client (Android).
	```
	vi android.conf
	```

	[android.conf]
	```
	[Interface]
	Address = 192.168.222.2/32
	PrivateKey = <content of android.private>
	
	[Peer]
	PublicKey = <content of freebsd.public>
	AllowedIPs = 192.168.222.1/32
	Endpoint = wg.example.com:51820
	```

4. Start WireGuard service on the server.
	```
	sysrc wireguard_enable="YES"
	sysrc wireguard_interfaces="wg0"
	service wireguard start
	```

5. Display a QR code representing the Android configuration.
	```
	qrencode -t ansi < android.conf
	```

### Android
1. Start WireGuard app.
2. Tap [+] button.
3. Select "Create from QR code".
4. Scan the QR code displayed on the FreeBSD's terminal.
5. Input an arbitrary string for "Tunnel Name".
6. Tap "CREATE TUNNEL".
7. Enable the tunnel.

## Test with Ping
### Android on 4G
At this stage, the Android phone was connected to 4G network.

I observed packets on the FreeBSD's external and WireGuard interfaces while I ran ping from the Android to the FreeBSD's internal address.

[Android] Using Local Shell on ConnectBot  
I got ping replys successfully.
```
ping 192.168.222.1
```

[FreeBSD] External Interface  
I saw WireGuard's UDP packets between the Android and FreeBSD's external addresses. Contents of the packets looked encrypted.
```
sudo tcpdump -vln -X -i vtnet0
...
14:14:55.589817 IP (tos 0x0, ttl 51, id 11367, offset 0, flags [DF], proto UDP (17), length 156)
    yyy.yyy.yyy.yyy.62553 > xxx.xxx.xxx.xxx.51820: UDP, length 128
        0x0000: 4500 009c 2c67 4000 3311 e12b YYYY YYYY E...,g@.3..+....
        0x0010: XXXX XXXX f459 ca6c 0088 0cfe 0400 0000 .....Y.l........
        0x0020: e5c9 99e9 1900 0000 0000 0000 57ca 4f01 ............W.O.
        0x0030: ba31 065c cf73 da5d 7010 760c 2b2b a358 .1.\.s.]p.v.++.X
        0x0040: 5f28 0fe2 0efd 30de b3ca 4e15 bc57 a511 _(....0...N..W..
        0x0050: 45ba 9b61 7bcd 751a 10bd 31ab d803 7bbd E..a{.u...1...{.
        0x0060: f125 ddd2 e5f6 08a9 d676 9c97 5f73 81c5 .%.......v.._s..
        0x0070: 46cb df15 445a 6651 cdfe 4256 79c1 b56b F...DZfQ..BVy..k
        0x0080: 787e 30f4 e8da 4c80 bea1 31c7 ec41 c2ac x~0...L...1..A..
        0x0090: 1998 35f4 fff4 058a b8f6 6e68 ..5.......nh
14:14:55.590192 IP (tos 0x0, ttl 64, id 21519, offset 0, flags [none], proto UDP (17), length 156)
    xxx.xxx.xxx.xxx.51820 > yyy.yyy.yyy.yyy.62553: UDP, length 128
        0x0000: 4500 009c 540f 0000 4011 ec83 XXXX XXXX E...T...@.......
        0x0010: YYYY YYYY ca6c f459 0088 3a58 0400 0000 .....l.Y..:X....
        0x0020: 811d adb9 1900 0000 0000 0000 fd3b 52e9 .............;R.
        0x0030: 156c 2e34 a863 28f5 ee0b a025 7cb3 a909 .l.4.c(....%|...
        0x0040: 24b2 792f 8cbf ccdc dda9 442d 5bda 7e33 $.y/......D-[.~3
        0x0050: 0e38 644c 0074 809b 901c 85bf 452d 556d .8dL.t......E-Um
        0x0060: b4d8 04b3 7df9 7299 de28 85e5 3849 7bc1 ....}.r..(..8I{.
        0x0070: 14af 252f 5b13 1831 5d89 dbd1 1adb cbf5 ..%/[..1].......
        0x0080: 268a b4ec 3f1b b049 7c4b bb61 b007 fe16 &...?..I|K.a....
        0x0090: e372 9a33 9a9f f30f e5bc ee91 .r.3........
```

[FreeBSD] WireGuard Interface  
I could see plain ping packets between the Android and FreeBSD's internal addresses.
```
sudo tcpdump -vln -X -i wg0
...
14:14:54.590165 IP (tos 0x0, ttl 64, id 51967, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.222.2 > 192.168.222.1: ICMP echo request, id 16, seq 25, length 64
        0x0000: 4500 0054 caff 4000 4001 3254 c0a8 de02 E..T..@.@.2T....
        0x0010: c0a8 de01 0800 cf8d 0010 0019 6025 475c ............`%G\
        0x0020: 0000 0000 bff4 0200 0000 0000 1011 1213 ................
        0x0030: 1415 1617 1819 1a1b 1c1d 1e1f 2021 2223 .............!"#
        0x0040: 2425 2627 2829 2a2b 2c2d 2e2f 3031 3233 $%&'()*+,-./0123
        0x0050: 3435 3637 4567
14:14:54.590183 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.222.1 > 192.168.222.2: ICMP echo reply, id 16, seq 25, length 64
        0x0000: 4500 0054 0000 4000 4001 fd53 c0a8 de01 E..T..@.@..S....
        0x0010: c0a8 de02 0000 d78d 0010 0019 6025 475c ............`%G\
        0x0020: 0000 0000 bff4 0200 0000 0000 1011 1213 ................
        0x0030: 1415 1617 1819 1a1b 1c1d 1e1f 2021 2223 .............!"#
        0x0040: 2425 2627 2829 2a2b 2c2d 2e2f 3031 3233 $%&'()*+,-./0123
        0x0050: 3435 3637 4567
```

[FreeBSD] WireGuard status  
Peer's endpoint was the one for 4G network.
```
wg show
interface: wg0
  public key: ZnytpGElvUA1yxcdjhIqZ4L3NxZmbMJBdC9IvI5giUA=
  private key: (hidden)
  listening port: 51820

peer: DFrE6f3TM1mVhFE8WLCgcEjCJHwfcj2T6xUt/Rzk6VY=
  endpoint: yyy.yyy.yyy.yyy:62553
  allowed ips: 192.168.222.2/32
  latest handshake: 15 seconds ago
  transfer: 7.96 KiB received, 12.12 KiB sent
```

### Android Moved to WiFi
Then I turned on the Android's WiFi and saw what happened.

[Android] Using ConnectBot's Local Shell   
Surprisingly, ping replys continued without break.

[FreeBSD] External Interface  
Client's IP address was changed to the home router's external address because the Android phone was now connected to the home WiFi and its private address was NATed by the router.
```
14:14:57.551820 IP (tos 0x0, ttl 45, id 47299, offset 0, flags [DF], proto UDP (17), length 156)
    zzz.zzz.zzz.zzz.60259 > xxx.xxx.xxx.xxx.51820: UDP, length 128
        0x0000: 4500 009c b8c3 4000 2d11 41bb ZZZZ ZZZZ E.....@.-.A.....
        0x0010: XXXX XXXX eb63 ca6c 0088 d099 0400 0000 .....c.l........
        0x0020: e5c9 99e9 1b00 0000 0000 0000 b807 f97f ................
        0x0030: 43be f570 044f f634 1649 4d1f b0c3 80da C..p.O.4.IM.....
        0x0040: 700a f1ec bc6a ee4b 50d6 e3c8 6505 d4c5 p....j.KP...e...
        0x0050: 881a 89de a5e2 65fc 9ada 6cd8 f131 1856 ......e...l..1.V
        0x0060: 460f 8760 ead0 946f 0227 1c75 1075 dd5f F..`...o.'.u.u._
        0x0070: 70e1 80b2 656d 0da7 0cf4 33c7 4206 deab p...em....3.B...
        0x0080: 7de3 bf2b 52d7 2477 1beb b5fb 9fb5 7454 }..+R.$w......tT
        0x0090: dd66 83ba 804c 1a7e 81f2 2b1c .f...L.~..+.
14:14:57.552265 IP (tos 0x0, ttl 64, id 21521, offset 0, flags [none], proto UDP (17), length 156)
    xxx.xxx.xxx.xxx.51820 > zzz.zzz.zzz.zzz.60259: UDP, length 128
        0x0000: 4500 009c 5411 0000 4011 d36d XXXX XXXX E...T...@..m....
        0x0010: ZZZZ ZZZZ ca6c eb63 0088 536c 0400 0000 .....l.c..Sl....
        0x0020: 811d adb9 1b00 0000 0000 0000 c84b 8ced .............K..
        0x0030: 9e81 a64f 275d eb5e 521d 3eaf bb0b e9fc ...O'].^R.>.....
        0x0040: 83ed a794 8b42 44b9 ec66 1d4a f87d 4057 .....BD..f.J.}@W
        0x0050: 7752 86a0 cef4 2482 3ada 7f06 ad5b 990a wR....$.:....[..
        0x0060: 387a ae61 ab1d 8989 9bd5 a5dc cad3 37ec 8z.a..........7.
        0x0070: 6f79 5a0b 2ce9 3c3e efdf 3f53 614a 3ba5 oyZ.,.<>..?SaJ;.
        0x0080: 25b2 353f 8f6d c494 742f 2a2e 32b2 401d %.5?.m..t/*.2.@.
        0x0090: afcf a584 1557 9845 0ce5 d9c0 .....W.E....
```

[FreeBSD] WireGuard Interface  
On the WireGuard interface, plain ping packets kept flowing as if nothing happened.
```
14:14:57.552188 IP (tos 0x0, ttl 64, id 52033, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.222.2 > 192.168.222.1: ICMP echo request, id 16, seq 28, length 64
        0x0000: 4500 0054 cb41 4000 4001 3212 c0a8 de02 E..T.A@.@.2.....
        0x0010: c0a8 de01 0800 9674 0010 001c 6325 475c .......t....c%G\
        0x0020: 0000 0000 f50a 0300 0000 0000 1011 1213 ................
        0x0030: 1415 1617 1819 1a1b 1c1d 1e1f 2021 2223 .............!"#
        0x0040: 2425 2627 2829 2a2b 2c2d 2e2f 3031 3233 $%&'()*+,-./0123
        0x0050: 3435 3637 4567
14:14:57.552205 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto ICMP (1), length 84)
    192.168.222.1 > 192.168.222.2: ICMP echo reply, id 16, seq 28, length 64
        0x0000: 4500 0054 0000 4000 4001 fd53 c0a8 de01 E..T..@.@..S....
        0x0010: c0a8 de02 0000 9e74 0010 001c 6325 475c .......t....c%G\
        0x0020: 0000 0000 f50a 0300 0000 0000 1011 1213 ................
        0x0030: 1415 1617 1819 1a1b 1c1d 1e1f 2021 2223 .............!"#
        0x0040: 2425 2627 2829 2a2b 2c2d 2e2f 3031 3233 $%&'()*+,-./0123
        0x0050: 3435 3637 4567
```

[FreeBSD] WireGuard status  
Peer's endpoint was updated.
```
wg show
interface: wg0
  public key: ZnytpGElvUA1yxcdjhIqZ4L3NxZmbMJBdC9IvI5giUA=
  private key: (hidden)
  listening port: 51820

peer: DFrE6f3TM1mVhFE8WLCgcEjCJHwfcj2T6xUt/Rzk6VY=
  endpoint: zzz.zzz.zzz.zzz:60259
  allowed ips: 192.168.222.2/32
  latest handshake: 5 seconds ago
  transfer: 8.12 KiB received, 12.85 KiB sent
```

Okay. Now I deleted the VPN connection on the Android phone and destroyed the droplet.

## References
* WireGuard  
<https://www.wireguard.com/>

* WireGuard for FreeBSD  
<https://lists.freebsd.org/pipermail/freebsd-ports/2018-May/113434.html>

* WireGuard App for Android - Google Play  
<https://play.google.com/store/apps/details?id=com.wireguard.android>

## Revision History
* 2019-01-23: Created
