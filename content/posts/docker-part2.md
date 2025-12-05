---
title: "Docker: Stop using it the wrong way. Part 2."
author: "Max Norin"
type: "post"
subtitle: "A grownup is a child with layers on. (c) Woody Harrelson"
image: ""
tags: ["docker", "linux", "nginx"]
date: 2018-11-20T21:40:07+13:00
draft: false
---

Layers is a very important subject when it comes to Docker images. We will create a docker container image built in a "traditional" way and then we will try to make it smaller. Let's make a container that runs a webserver. 
Nginx is a good option to start with. It's small, fast, it has a lot of modules, very flexible in terms of settings and well-documented, therefore I strongly recommend to get yourself familiar with it if you are still not.

### How to build Docker images

Before we start we need to understand how to build Docker images.

First thing you need to do is to create file named "Dockerfile". This file will contain instructions for Docker that will tell it what we need to have inside the container image.

Detailed information on these instructions and best practices you can find <a href="https://docs.docker.com/develop/develop-images/dockerfile_best-practices/" title="Docker best practices" target="_blank">here</a>, on the official Docker website.

Here it is:

{{< highlight docker >}}

FROM debian:latest

RUN apt-get update
RUN apt-get -y install nginx

CMD ["nginx","-g","daemon off;"]

{{< /highlight >}}

And now we can build the container image using this command:

{{< highlight bash >}}

docker build -t local/nginx:default .

{{< /highlight >}}

And now we can look how big is the image:

{{< highlight bash >}}

$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
local/nginx         default             68e66d48554d        6 seconds ago       177MB

{{< /highlight >}}

Well, 177MB for my taste is too much for a web server. Let's make it smaller. But first thigs first, we need to understand what just happened here.

### How many layers do we have?

As I already mentioned above, every instruction in Dockerfile creates a layer. In this example we have three layers that are really interesting, FROM, RUN and another RUN.

Instruction FROM takes already existing image and uses it as the first level, instructions RUN create some file system objects, every RUN creates its own file system changes.
Guess what happens when you use these two instruction?

{{< highlight docker >}}

RUN apt-get -y install nginx
RUN apt-get clean

{{< /highlight >}}

### What is wrong with it?

First of all, you will get an image without all these cached packages you installed, BUT images technically still has these files. They will be stored on the lower layer, and the size of this lower layer will be bigger, so as the whole image size.
To avoid this situation you should remove all unnecessary files in the same layer you create them.

Secondly, the smaller the base image, the smaller will be your final image (most likely, because you can actually install all the packages included in the bigger image). Plus package manager can install some packages it considers recommended.
It is another thing we don't really need.

Layer should only include file system additions you will need to be in the final Docker image if it's possible.

Let's optimize it a little.

{{< highlight docker >}}

FROM debian:stretch-slim

RUN apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y nginx-light &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

CMD ["nginx","-g","daemon off;"]

{{< /highlight >}}

And now repeat building

{{< highlight bash >}}

docker build -t local/nginx:default .

{{< /highlight >}}

What do we have now?

{{< highlight bash >}}

$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
local/nginx         default             3ab54452b20f        4 seconds ago       61.5MB

{{< /highlight >}}

Well, it's much smaller now. Small enough to use it. But for my taste it's still pretty big for only a web server that starts and actually only shows one simple web page.

### Can we make it even smaller?

Absolutely!

But we need to know some more to be able to do it:

- What config files we need
- What libraries we need
- How to take only what we need and not to take everything else?

Let's go with numbers and then clarify details.

1. The most important things first. Docker allows you to use multi-stage builds. What does it mean? It means, that you can build few images from one Dockerfile. For example, you build first image, you include some compilers, linkers, and other files necessary to
compile and build your application from the sorce code. After that you can create another docker image and copy your app and all files it needs to the second one, which will be used to run your application.

2. All the config files for nginx are placed to /etc/nginx, so you can just copy this directory

3. To figure out which libraries you need, you need to understand how applications in Linux work. All the application, which built with dynamic libraries, use runtime linker, ld.so (actual file name can be different, we'll see it later). When app starts, 
it sends to linker the list of libraries it needs to run. Linker finds these libraries and loads them in memory and then tells the apps, that all the libraries are loaded, and it can execute. Also, some app can load modules and these modules can use some other
libraries.

4. Linker has a list of directories it uses to search for libraries files, if it can find them, it will load them, if it can not, then obviously no, and in this case your app will not work.

5. To run the app we don't even need a shell.

6. The smallest docker base image you can use named "scratch", and this image size is zero bytes.

Now let's get to the practice.

To figure out first set of libraries for nginx we'll need to use program ldd, this program tells which libraries the application needs to start. For nginx it will be like this:

{{< highlight bash >}}

$ ldd $(which nginx)
        linux-vdso.so.1 (0x00007fff200bc000)
        libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007ff5ec189000)
        libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007ff5ebf6c000)
        libcrypt.so.1 => /lib/x86_64-linux-gnu/libcrypt.so.1 (0x00007ff5ebd34000)
        libpcre.so.3 => /lib/x86_64-linux-gnu/libpcre.so.3 (0x00007ff5ebac1000)
        libssl.so.1.1 => /usr/lib/x86_64-linux-gnu/libssl.so.1.1 (0x00007ff5eb855000)
        libcrypto.so.1.1 => /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 (0x00007ff5eb3c2000)
        libz.so.1 => /lib/x86_64-linux-gnu/libz.so.1 (0x00007ff5eb1a8000)
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007ff5eae09000)
        /lib64/ld-linux-x86-64.so.2 (0x00007ff5ec6ae000)

{{< /highlight >}}

### What is what?

linux-vdso.so.1 is a linux kernel library, so you don't have to look for a file. More details you can find if you use command

{{< highlight bash >}}

man 7 vdso

{{< /highlight >}}

/lib64/ld-linux-x86-64.so.2 is the linker (ld.so). We definitely need this one, otherwise your app will not be able to use other libraries. For more details read man page

{{< highlight bash >}}

man ld.so

{{< /highlight >}}

All other libraries we also need, and ldd shows where to get them. So, we'll need to copy all of them.

Next step: we need to make sure we know all the libraries that nginx is supposed to use. To figure it out we'll need to trace system calls with program strace (it won't hurt to also check the man page, by the way). 

This is what it looks like for the full nginx version (not light one we install in the last Dockerfile):

{{< highlight bash >}}

# strace /usr/sbin/nginx -g 'daemon off;' 2>&1 | grep -E '^(open|read|fstat)'
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/lib/x86_64-linux-gnu/libdl.so.2", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200\r\300%3\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=17272, ...}) = 0
open("/lib/x86_64-linux-gnu/libpthread.so.0", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0Pa\0&3\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0755, st_size=138760, ...}) = 0
open("/lib/x86_64-linux-gnu/libcrypt.so.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0p\v\0\0\0\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=39256, ...}) = 0
open("/lib/x86_64-linux-gnu/libpcre.so.3", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\320\25\200'3\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=471328, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libssl.so.1.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\360\211\1\0\0\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=442920, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0\340\7\0\0\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=2686672, ...}) = 0
open("/lib/x86_64-linux-gnu/libz.so.1", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300!@&3\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0644, st_size=107656, ...}) = 0
open("/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
read(3, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0\4B%3\0\0\0"..., 832) = 832
fstat(3, {st_mode=S_IFREG|0755, st_size=1694760, ...}) = 0
open("/etc/localtime", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=2460, ...}) = 0
fstat(3, {st_mode=S_IFREG|0644, st_size=2460, ...}) = 0
read(3, "TZif2\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\7\0\0\0\7\0\0\0\0"..., 4096) = 2460
read(3, "TZif2\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\7\0\0\0\7\0\0\0\0"..., 4096) = 1561
open("/var/log/nginx/error.log", O_WRONLY|O_CREAT|O_APPEND, 0644) = 3
open("/usr/lib/ssl/openssl.cnf", O_RDONLY) = 4
fstat(4, {st_mode=S_IFREG|0644, st_size=10846, ...}) = 0
read(4, "#\n# OpenSSL example configuratio"..., 4096) = 4096
read(4, "ons of Netscape crash on BMPStri"..., 4096) = 4096
read(4, "\n# requires this to avoid interp"..., 4096) = 2654
read(4, "", 4096)                       = 0
open("/sys/devices/system/cpu/online", O_RDONLY|O_CLOEXEC) = 4
read(4, "0-3\n", 8192)                  = 4
open("/etc/nginx/nginx.conf", O_RDONLY) = 4
fstat(4, {st_mode=S_IFREG|0644, st_size=1505, ...}) = 0
open("/etc/nsswitch.conf", O_RDONLY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=529, ...}) = 0
read(5, "# /etc/nsswitch.conf\n#\n# Example"..., 4096) = 529
read(5, "", 4096)                       = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/lib/x86_64-linux-gnu/libnss_compat.so.2", O_RDONLY|O_CLOEXEC) = 5
read(5, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\260\22\0\0\0\0\0\0"..., 832) = 832
fstat(5, {st_mode=S_IFREG|0644, st_size=31616, ...}) = 0
open("/lib/x86_64-linux-gnu/libnsl.so.1", O_RDONLY|O_CLOEXEC) = 5
read(5, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\320?@'3\0\0\0"..., 832) = 832
fstat(5, {st_mode=S_IFREG|0644, st_size=91696, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/lib/x86_64-linux-gnu/libnss_nis.so.2", O_RDONLY|O_CLOEXEC) = 5
read(5, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\340 \0\0\0\0\0\0"..., 832) = 832
fstat(5, {st_mode=S_IFREG|0644, st_size=47688, ...}) = 0
open("/lib/x86_64-linux-gnu/libnss_files.so.2", O_RDONLY|O_CLOEXEC) = 5
read(5, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\320!\0\0\0\0\0\0"..., 832) = 832
fstat(5, {st_mode=S_IFREG|0644, st_size=47632, ...}) = 0
open("/etc/passwd", O_RDONLY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=3016, ...}) = 0
open("/etc/group", O_RDONLY|O_CLOEXEC)  = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=1422, ...}) = 0
open("/etc/nginx/modules-enabled", O_RDONLY|O_NONBLOCK|O_DIRECTORY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-auth-pam.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=49, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_auth_pam_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0@\16\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=10680, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/lib/x86_64-linux-gnu/libpam.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\260&\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=56016, ...}) = 0
open("/lib/x86_64-linux-gnu/libaudit.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0-\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=120752, ...}) = 0
open("/lib/x86_64-linux-gnu/libcap-ng.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20\25\340_5\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=25496, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-dav-ext.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=48, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_dav_ext_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\360\21\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=18824, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/lib/x86_64-linux-gnu/libexpat.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20; +3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=172632, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-echo.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=45, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_echo_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\2202\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=45208, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-geoip.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=46, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_geoip_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0 \27\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=20232, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libGeoIP.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20l@m8\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=205248, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-image-filter.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=53, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_image_filter_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\320\26\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=23440, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libgd.so.3", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20\335\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=406184, ...}) = 0
open("/lib/x86_64-linux-gnu/libm.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200V\200%3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1065952, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libpng16.so.16", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20P`+3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=209192, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libfontconfig.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\240l\340*3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=255672, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libfreetype.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0`\1a)3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=719328, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libjpeg.so.62", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0p:@(3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=438664, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libXpm.so.4", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0p0@\236<\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=75568, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libX11.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\240\335\241-3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1313016, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libtiff.so.5", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0\177\300(3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=488528, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libwebp.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300%\0 >\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=394408, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libxcb.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0@\273\340.3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=165464, ...}) = 0
open("/lib/x86_64-linux-gnu/liblzma.so.5", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\2200\300&3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=157008, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libjbig.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\360\22\0(3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=60888, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libXau.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20\20\240/3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=16984, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libXdmcp.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0@\23 03\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=25264, ...}) = 0
open("/lib/x86_64-linux-gnu/libbsd.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\3203`/3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=86704, ...}) = 0
open("/lib/x86_64-linux-gnu/librt.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\340 \200&3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=34608, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-subs-filter.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=52, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_subs_filter_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\20\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=18984, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-upstream-fair.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=54, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_upstream_fair_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0P\16\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=18728, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-http-xslt-filter.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=52, ...}) = 0
open("/usr/share/nginx/modules/ngx_http_xslt_filter_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\30\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=19304, ...}) = 0
open("/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=218859, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libxml2.so.2", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\343\242M0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1812432, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libxslt.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\300\240`M0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=258952, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libexslt.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\0008\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=87912, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libicui18n.so.57", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0p\22\214L0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=2594624, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libicuuc.so.57", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\360\311\205J0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1729984, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libicudata.so.57", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\20\5\300J0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=25677880, ...}) = 0
open("/lib/x86_64-linux-gnu/libgcrypt.so.20", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200\255\240J5\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1114656, ...}) = 0
open("/usr/lib/x86_64-linux-gnu/libstdc++.so.6", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\3\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\340\267\310'3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=1569104, ...}) = 0
open("/lib/x86_64-linux-gnu/libgcc_s.so.1", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\220*\0'3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=95088, ...}) = 0
open("/lib/x86_64-linux-gnu/libgpg-error.so.0", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0p(\300(3\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=82376, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-mail.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=40, ...}) = 0
open("/usr/share/nginx/modules/ngx_mail_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\200D\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=99592, ...}) = 0
open("/etc/nginx/modules-enabled/50-mod-stream.conf", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=42, ...}) = 0
open("/usr/share/nginx/modules/ngx_stream_module.so", O_RDONLY|O_CLOEXEC) = 6
read(6, "\177ELF\2\1\1\0\0\0\0\0\0\0\0\0\3\0>\0\1\0\0\0\360<\0\0\0\0\0\0"..., 832) = 832
fstat(6, {st_mode=S_IFREG|0644, st_size=78768, ...}) = 0
open("/etc/nginx/mime.types", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=3957, ...}) = 0
open("/etc/nginx/conf.d", O_RDONLY|O_NONBLOCK|O_DIRECTORY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
open("/etc/nginx/sites-enabled", O_RDONLY|O_NONBLOCK|O_DIRECTORY|O_CLOEXEC) = 5
fstat(5, {st_mode=S_IFDIR|0755, st_size=4096, ...}) = 0
open("/etc/nginx/sites-enabled/default", O_RDONLY) = 5
fstat(5, {st_mode=S_IFREG|0644, st_size=2428, ...}) = 0
open("/var/log/nginx/access.log", O_WRONLY|O_CREAT|O_APPEND, 0644) = 4
open("/var/log/nginx/error.log", O_WRONLY|O_CREAT|O_APPEND, 0644) = 5
open("/run/nginx.pid", O_RDWR|O_CREAT|O_TRUNC, 0644) = 7

{{< /highlight >}}

These are all the files, and some of them are not in the first list. Let's make the full list for the full version (sorted by directory):

{{< highlight bash >}}

/etc/ld.so.cache
/etc/localtime
/etc/nsswitch.conf
/etc/passwd
/etc/group
/etc/nginx/nginx.conf
/etc/nginx/modules-enabled
/etc/nginx/modules-enabled/50-mod-http-auth-pam.conf
/etc/nginx/modules-enabled/50-mod-http-dav-ext.conf
/etc/nginx/modules-enabled/50-mod-http-echo.conf
/etc/nginx/modules-enabled/50-mod-http-geoip.conf
/etc/nginx/modules-enabled/50-mod-http-image-filter.conf
/etc/nginx/modules-enabled/50-mod-http-subs-filter.conf
/etc/nginx/modules-enabled/50-mod-http-upstream-fair.conf
/etc/nginx/modules-enabled/50-mod-http-xslt-filter.conf
/etc/nginx/modules-enabled/50-mod-mail.conf
/etc/nginx/modules-enabled/50-mod-stream.conf
/etc/nginx/mime.types
/etc/nginx/conf.d
/etc/nginx/sites-enabled
/etc/nginx/sites-enabled/default
/lib/x86_64-linux-gnu/libdl.so.2
/lib/x86_64-linux-gnu/libpthread.so.0
/lib/x86_64-linux-gnu/libcrypt.so.1
/lib/x86_64-linux-gnu/libpcre.so.3
/lib/x86_64-linux-gnu/libz.so.1
/lib/x86_64-linux-gnu/libc.so.6
/lib/x86_64-linux-gnu/libnss_compat.so.2
/lib/x86_64-linux-gnu/libnsl.so.1
/lib/x86_64-linux-gnu/libnss_nis.so.2
/lib/x86_64-linux-gnu/libnss_files.so.2
/lib/x86_64-linux-gnu/libpam.so.0
/lib/x86_64-linux-gnu/libaudit.so.1
/lib/x86_64-linux-gnu/libcap-ng.so.0
/lib/x86_64-linux-gnu/libexpat.so.1
/lib/x86_64-linux-gnu/libm.so.6
/lib/x86_64-linux-gnu/liblzma.so.5
/lib/x86_64-linux-gnu/libbsd.so.0
/lib/x86_64-linux-gnu/librt.so.1
/lib/x86_64-linux-gnu/libgcrypt.so.20
/lib/x86_64-linux-gnu/libgcc_s.so.1
/lib/x86_64-linux-gnu/libgpg-error.so.0
/usr/lib/x86_64-linux-gnu/libssl.so.1.1
/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
/usr/lib/x86_64-linux-gnu/libgd.so.3
/usr/lib/x86_64-linux-gnu/libpng16.so.16
/usr/lib/x86_64-linux-gnu/libfontconfig.so.1
/usr/lib/x86_64-linux-gnu/libfreetype.so.6
/usr/lib/x86_64-linux-gnu/libjpeg.so.62
/usr/lib/x86_64-linux-gnu/libXpm.so.4
/usr/lib/x86_64-linux-gnu/libX11.so.6
/usr/lib/x86_64-linux-gnu/libtiff.so.5
/usr/lib/x86_64-linux-gnu/libwebp.so.6
/usr/lib/x86_64-linux-gnu/libxcb.so.1
/usr/lib/x86_64-linux-gnu/libjbig.so.0
/usr/lib/x86_64-linux-gnu/libXau.so.6
/usr/lib/x86_64-linux-gnu/libXdmcp.so.6
/usr/lib/x86_64-linux-gnu/libxml2.so.2
/usr/lib/x86_64-linux-gnu/libxslt.so.1
/usr/lib/x86_64-linux-gnu/libexslt.so.0
/usr/lib/x86_64-linux-gnu/libicui18n.so.57
/usr/lib/x86_64-linux-gnu/libicuuc.so.57
/usr/lib/x86_64-linux-gnu/libicudata.so.57
/usr/lib/x86_64-linux-gnu/libGeoIP.so.1
/usr/lib/x86_64-linux-gnu/libstdc++.so.6
/usr/lib/ssl/openssl.cnf
/usr/share/nginx/modules/ngx_http_auth_pam_module.so
/usr/share/nginx/modules/ngx_http_dav_ext_module.so
/usr/share/nginx/modules/ngx_http_echo_module.so
/usr/share/nginx/modules/ngx_http_geoip_module.so
/usr/share/nginx/modules/ngx_http_image_filter_module.so
/usr/share/nginx/modules/ngx_http_subs_filter_module.so
/usr/share/nginx/modules/ngx_http_upstream_fair_module.so
/usr/share/nginx/modules/ngx_http_xslt_filter_module.so
/usr/share/nginx/modules/ngx_mail_module.so
/usr/share/nginx/modules/ngx_stream_module.so
/sys/devices/system/cpu/online
/var/log/nginx/access.log
/var/log/nginx/error.log
/run/nginx.pid

{{< /highlight >}}

OK, we are getting closer. Now we need to make sure we get it right. We definitely need everything from /etc/nginx and /usr/share/nginx. But we don't need /var/log/nginx, /run/nginx.pid, /sys/devices/system/cpu/online and /etc/ld.so.cache. The final list:

{{< highlight bash >}}

/etc/nginx/
/usr/share/nginx/
/etc/nsswitch.conf
/etc/passwd
/etc/group
/etc/ld.so.conf
/etc/ld.so.conf.d/
/lib64/ld-linux-x86-64.so.2
/lib/x86_64-linux-gnu/libdl.so.2
/lib/x86_64-linux-gnu/libpthread.so.0
/lib/x86_64-linux-gnu/libcrypt.so.1
/lib/x86_64-linux-gnu/libpcre.so.3
/lib/x86_64-linux-gnu/libz.so.1
/lib/x86_64-linux-gnu/libc.so.6
/lib/x86_64-linux-gnu/libnss_compat.so.2
/lib/x86_64-linux-gnu/libnsl.so.1
/lib/x86_64-linux-gnu/libnss_nis.so.2
/lib/x86_64-linux-gnu/libnss_files.so.2
/lib/x86_64-linux-gnu/libpam.so.0
/lib/x86_64-linux-gnu/libaudit.so.1
/lib/x86_64-linux-gnu/libcap-ng.so.0
/lib/x86_64-linux-gnu/libexpat.so.1
/lib/x86_64-linux-gnu/libm.so.6
/lib/x86_64-linux-gnu/liblzma.so.5
/lib/x86_64-linux-gnu/libbsd.so.0
/lib/x86_64-linux-gnu/librt.so.1
/lib/x86_64-linux-gnu/libgcrypt.so.20
/lib/x86_64-linux-gnu/libgcc_s.so.1
/lib/x86_64-linux-gnu/libgpg-error.so.0
/usr/lib/x86_64-linux-gnu/libssl.so.1.1
/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
/usr/lib/x86_64-linux-gnu/libgd.so.3
/usr/lib/x86_64-linux-gnu/libpng16.so.16
/usr/lib/x86_64-linux-gnu/libfontconfig.so.1
/usr/lib/x86_64-linux-gnu/libfreetype.so.6
/usr/lib/x86_64-linux-gnu/libjpeg.so.62
/usr/lib/x86_64-linux-gnu/libXpm.so.4
/usr/lib/x86_64-linux-gnu/libX11.so.6
/usr/lib/x86_64-linux-gnu/libtiff.so.5
/usr/lib/x86_64-linux-gnu/libwebp.so.6
/usr/lib/x86_64-linux-gnu/libxcb.so.1
/usr/lib/x86_64-linux-gnu/libjbig.so.0
/usr/lib/x86_64-linux-gnu/libXau.so.6
/usr/lib/x86_64-linux-gnu/libXdmcp.so.6
/usr/lib/x86_64-linux-gnu/libxml2.so.2
/usr/lib/x86_64-linux-gnu/libxslt.so.1
/usr/lib/x86_64-linux-gnu/libexslt.so.0
/usr/lib/x86_64-linux-gnu/libicui18n.so.57
/usr/lib/x86_64-linux-gnu/libicuuc.so.57
/usr/lib/x86_64-linux-gnu/libicudata.so.57
/usr/lib/x86_64-linux-gnu/libGeoIP.so.1
/usr/lib/x86_64-linux-gnu/libstdc++.so.6

{{< /highlight >}}

### How to put it all together?

To put all this stuff together we will need to use multi-stage Docker image build. This feature is pretty fresh, but very convenient. This is how it works:

1. We create an image that contains everything necessary to compile and build your application (or install all the packages)
2. We create another image (we can use another base image OR build it from "scratch", which is the most efficient way)
3. We copy all we need to this second image using Dockerfile instructions

And the most interesting part: we can keep both images and use first one for the development environment, where we need to have all the tools inside the container to be able to debug the app or get some other information, and the second one we can use in production.

This is how this multi-stage Dockerfile looks:

{{< highlight docker >}}

FROM debian:stretch-slim as dev

RUN apt-get update &&\
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y nginx &&\
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/* &&\
  sed -i /etc/nginx/sites-enabled/default -e 's/listen \[::\]:80/# listen \[::\]:80/'

FROM scratch

COPY --from=dev /etc/nginx/ /etc/nginx
COPY --from=dev /usr/share/nginx/ /usr/share/nginx/
COPY --from=dev /usr/sbin/nginx /usr/sbin/nginx
COPY --from=dev /etc/nsswitch.conf /etc/nsswitch.conf
COPY --from=dev /etc/passwd /etc/passwd
COPY --from=dev /etc/group /etc/group
COPY --from=dev /etc/ld.so.conf /etc/ld.so.conf
COPY --from=dev /etc/ld.so.conf.d/ /etc/ld.so.conf.d/
COPY --from=dev /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=dev /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=dev /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=dev /lib/x86_64-linux-gnu/libcrypt.so.1 /lib/x86_64-linux-gnu/libcrypt.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libpcre.so.3 /lib/x86_64-linux-gnu/libpcre.so.3
COPY --from=dev /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=dev /lib/x86_64-linux-gnu/libnss_compat.so.2 /lib/x86_64-linux-gnu/libnss_compat.so.2
COPY --from=dev /lib/x86_64-linux-gnu/libnsl.so.1 /lib/x86_64-linux-gnu/libnsl.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libnss_nis.so.2 /lib/x86_64-linux-gnu/libnss_nis.so.2
COPY --from=dev /lib/x86_64-linux-gnu/libnss_files.so.2 /lib/x86_64-linux-gnu/libnss_files.so.2
COPY --from=dev /lib/x86_64-linux-gnu/libpam.so.0 /lib/x86_64-linux-gnu/libpam.so.0
COPY --from=dev /lib/x86_64-linux-gnu/libaudit.so.1 /lib/x86_64-linux-gnu/libaudit.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libcap-ng.so.0 /lib/x86_64-linux-gnu/libcap-ng.so.0
COPY --from=dev /lib/x86_64-linux-gnu/libexpat.so.1 /lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=dev /lib/x86_64-linux-gnu/liblzma.so.5 /lib/x86_64-linux-gnu/liblzma.so.5
COPY --from=dev /lib/x86_64-linux-gnu/libbsd.so.0 /lib/x86_64-linux-gnu/libbsd.so.0
COPY --from=dev /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libgcrypt.so.20 /lib/x86_64-linux-gnu/libgcrypt.so.20
COPY --from=dev /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/libgcc_s.so.1
COPY --from=dev /lib/x86_64-linux-gnu/libgpg-error.so.0 /lib/x86_64-linux-gnu/libgpg-error.so.0
COPY --from=dev /usr/lib/x86_64-linux-gnu/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libgd.so.3 /usr/lib/x86_64-linux-gnu/libgd.so.3
COPY --from=dev /usr/lib/x86_64-linux-gnu/libpng16.so.16 /usr/lib/x86_64-linux-gnu/libpng16.so.16
COPY --from=dev /usr/lib/x86_64-linux-gnu/libfontconfig.so.1 /usr/lib/x86_64-linux-gnu/libfontconfig.so.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /usr/lib/x86_64-linux-gnu/libfreetype.so.6
COPY --from=dev /usr/lib/x86_64-linux-gnu/libjpeg.so.62 /usr/lib/x86_64-linux-gnu/libjpeg.so.62
COPY --from=dev /usr/lib/x86_64-linux-gnu/libXpm.so.4 /usr/lib/x86_64-linux-gnu/libXpm.so.4
COPY --from=dev /usr/lib/x86_64-linux-gnu/libX11.so.6 /usr/lib/x86_64-linux-gnu/libX11.so.6
COPY --from=dev /usr/lib/x86_64-linux-gnu/libtiff.so.5 /usr/lib/x86_64-linux-gnu/libtiff.so.5
COPY --from=dev /usr/lib/x86_64-linux-gnu/libwebp.so.6 /usr/lib/x86_64-linux-gnu/libwebp.so.6
COPY --from=dev /usr/lib/x86_64-linux-gnu/libxcb.so.1 /usr/lib/x86_64-linux-gnu/libxcb.so.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libjbig.so.0 /usr/lib/x86_64-linux-gnu/libjbig.so.0
COPY --from=dev /usr/lib/x86_64-linux-gnu/libXau.so.6 /usr/lib/x86_64-linux-gnu/libXau.so.6
COPY --from=dev /usr/lib/x86_64-linux-gnu/libXdmcp.so.6 /usr/lib/x86_64-linux-gnu/libXdmcp.so.6
COPY --from=dev /usr/lib/x86_64-linux-gnu/libxml2.so.2 /usr/lib/x86_64-linux-gnu/libxml2.so.2
COPY --from=dev /usr/lib/x86_64-linux-gnu/libxslt.so.1 /usr/lib/x86_64-linux-gnu/libxslt.so.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libexslt.so.0 /usr/lib/x86_64-linux-gnu/libexslt.so.0
COPY --from=dev /usr/lib/x86_64-linux-gnu/libicui18n.so.57 /usr/lib/x86_64-linux-gnu/libicui18n.so.57
COPY --from=dev /usr/lib/x86_64-linux-gnu/libicuuc.so.57 /usr/lib/x86_64-linux-gnu/libicuuc.so.57
COPY --from=dev /usr/lib/x86_64-linux-gnu/libicudata.so.57 /usr/lib/x86_64-linux-gnu/libicudata.so.57
COPY --from=dev /usr/lib/x86_64-linux-gnu/libGeoIP.so.1 /usr/lib/x86_64-linux-gnu/libGeoIP.so.1
COPY --from=dev /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/lib/x86_64-linux-gnu/libstdc++.so.6

CMD ["/usr/sbin/nginx","-g","daemon off;"]

EXPOSE 80
{{< /highlight >}}

Yes, it may be a little bit messy. But it only contains files we actually need (although you still can make it smaller). And here is the result size:

{{< highlight bash >}}

$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
local/nginx         default             166a08caf85d        6 minutes ago       48.5MB

{{< /highlight >}}

48.5 megabytes is much better than even 105 we had before. It's even smaller than the light version we had before. And it's more secure as we have nothing that you can use inside the container except the nginx binary.

### P.S.

I already mentioned that you can stop building after first image (dev) is finished. Just go and check the official Docker website.

### P.P.S.

Just to remind you: you can put your own config files inside the container using COPY instruction.

### P.P.P.S

If some of intermediate Dockerfiles don't work for you, it's because they are given just to explain what's happenning, they are not indended for the actual use. Also you should think about getting logs from containers before you build them.
For example, nginx may be configured to send logs to syslog.

### P.P.P.P.S

There are some scripts that can help you to reduce the docker image size, google it.
