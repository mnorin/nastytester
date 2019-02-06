---
title: "Docker: Stop using it the wrong way. Part 1."
author: "Max Norin"
type: "post"
date: 2018-11-20T19:59:36+13:00
subtitle: "If you're gonna do it, do it right (c) Wham!"
image: ""
tags: ["docker", "linux"]
---

Yes, that's right. Most likely if you use docker you do it the wrong way. The majority of people who try to use it start using it without bothering to understand, what is this all about, how it works and actually how it supposed to work.

If it works for you and you are happy about it then it's OK, keep doing it. If you want to know a little bit more about it and understand how to actually use it properly, I have something to tell you about it.

### Docker is not ...

... really a virtual machine. A proper virtual machine has a virtual hardware. Docker works on the same hardware host operating system does without a need to emulate devices. It work on the same kernel host system uses.
Actually, virtualization systems/hypervisors like OpenVZ also use host system kernel, but they do emulate VMs own devices.

... the same that LXC is. Some time ago Docker was built around LXC but it's a completely standalone containerization system since March 2014.

... the same that chroot or jail are. Yes, they look pretty much alike, but there are enough differences to say that these are different things.

### Docker is ...

... a containerization system (or operating system level virtualization system) plus tools and infrastructure that make certain things so much easier.

Docker allows to limit resources for a process or a group of processes using Linux kernel subsystem called cgroups (control groups), technically it creates a virtual environment and allows to limit it if necessary.
Plus you can create your own contaner images and use Docker images storage called repository to keep them and pull container images from it when you want to use them. 

### How it works

In the simplest case you just pull a container image to your computer (server/workstation/laptop - choose one) and then run a container based on the image to execute. When you run a container, it will start a program, command or script that defined to be an entry point.
From this moment the entry point executable object will be the main (or the only) process that will work inside the container

### Why do we need it?

OK, it's numbers time. There are different reasons to use it and I have to number them.

1) To guarantee that program works in its own specific environment not affected by any other programs. When you have a set of such specific environments you can create bigger (or even huge) information systems, every piece of each isolated in its environment BUT
it can communicate with other programs that work in their own environments. It allows you to create different parts of a big system using different technologies and write them in different programming languages.
Or you can use different versions of libraries without them interferring with each other. For example: PHP version 5.6 and PHP version 7.0. To keep both of them including all necessary modules and libraries on the same server may be not as trivial as you would 
probably like it, especially if you have plans to update them on a regular basis (I hope you have, because you have to anyway).

2) You can use the same parts for different Docker containers images. Let's say, you created a base container from an Ubuntu image and them built one image for MySQL and another one for Apache + PHP.
And in fact you will not need to store an initial Ubuntu image, the whole base image you created and both full images for these two services. You will only need to store an initial image, changes you made to it to create your base image
and changes you made to create these two final images from you base image. These changes you make are called layers. This word actually explains how it works, because the final docker container file system is formed by applying change OVER existing at the moment
file system. If it's not clear yet, check out this diagram:

<br>
<table>
<tr><th colspan=2 style="text-align:center">Docker image</th></tr>
<tr><td>Layer 3</td><td>Changes between base image and MySQL image</td></tr>
<tr><td>Layer 2</td><td>Changes between Ubuntu and your base image</td></tr>
<tr><td>Layer 1</td><td>Ubuntu</td></tr>
</table>
<br>

3) You can create a Docker image for your own application and publish it in a public repository (they can be public and private). Doing so you will help other people to get an installed and configured application in a couple of minutes
or even faster. As it works the opposite way also, you can use images created by other people without waisting your time on an app installation and configuration.

4) You can develop your application on your workstation and then use the same Docker image for your local test environment and a production system located in an Amazon or Google cloud the same way you use it on your computer (not literally the same way, but very close).

These are not the only reasons to use Docker, but it should be enough to start considering using it.

### What should be inside a Docker container?

There should be a program you plan to run, all files it needs to run (settings, libraries you wrote, directories that contain the program and all the files) and system libraries required to run your program. There is nothing else you ideally need to have there.

If you have only what you need and no more than that, than your program will be working as you expect it to and it's really good for security. If your application will be broken than an attacker will not be able to do much, if there is nothing else he could use.
If your conainer contains (sounds funny) the whole operating system, including a package manager and a set of compilers for different programming languages, then broken container can be an invasion point for your system, because it will be possible to compile an exploit
or some other unpleasant software to do a reconnaissance, start monitoring your network and so on.

Further we'll see how to minimize a container to make it as small as possible, including only what is necessary.
