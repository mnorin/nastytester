---
title: "Script that works in Windows and Linux"
author: "Max Norin"
type: "post"
date: 2019-03-10T18:51:08+13:00
subtitle: "There is no neat distinction between operating system software and the software that runs on top of it (c) Jim Allchin"
image: ""
tags: [linux,windows,bash,script]
draft: false
---

When you work with computers that run different operating systems, such as Linux and Windows, then you probably have some similar tasks you execute in both of them.
And for each operating system you write a separate script. Or may be you write programs in Java and for each operating system you have a script to set up an environment (sh-script or cmd-script).
If you need to do basically the same in Windows and in Linux, you can write only one script, that will work in both operating systems.

### Cross-platform script

It's pretty unlikely that you will use something like this in real life, so, just for fun, let's see how we can write a cross-platform script.

The main idea of a cross-platform script based on different use of similar script elements. I picked operator "goto", which is used in Windows batch files (.bat or .cmd).
There is no such operator in bash, for example, which will allow us to substitute it. The main task of the script will be simple, let it just print and operationg system name which it runs on.

As you may know, the first line in scripts for Linux is a name of interepreter that will be used to run the script.
We'll skip this line and let the current shell to execute it, instead of creating another shell instance. It's for good reasons, I swear.

First thing we should do is to disable printing commands we execute. By default Windows prints all the commands, and Linux does not. The first line of our script will be

{{< highlight bash >}}
echo off
{{< /highlight >}}

May be not he best option, because it will print the word "off" in Linux, but it's the only short option that occured to me that would work in both operating systems.

### Linux part

Next thing we should do is to write a function "goto", that will be executed when run in Linux.

{{< highlight bash >}}
goto(){
# Linux code here
uname -o
}
{{< /highlight >}}

From Linux perspective (bash perspective to be precise) it's a function, from Windows perspective it's a command "goto" that will go to the label "(){". It's a very important moment.

OK. Now we have a function, and we need to call it:

{{< highlight bash >}}
goto $@
exit
{{< /highlight >}}

For bash we call function "goto" and pass it a list of parameters that were set in the command line when we ran the script.
After this call we just exit the script. When we run the script, the main Linux script part is a function goto() body.

### Windows part
And now we need to add Windows part. It's even easier. After line that contains "exit" we just add this:

{{< highlight bash >}}
:(){
rem Windows script here
echo %OS%
{{< /highlight >}}

The line that contains ":(){" - it's a label we'll get if we run this script on Windows. Everything after this line and to the end of the file will be a script for Windows.

### And it's done

We got a script that works in both Linux and Windows, and even without errors. The only minus in this case - printed word "off" if you run the script in Linux, but it's a small thing I think we can live with.

Here is the whole script:

{{< highlight bash >}}
echo off

goto(){
# Linux code here
uname -o
}

goto $@
exit

:(){
rem Windows script here
echo %OS%
exit
{{< /highlight >}}

All this code (a bit bigger than 100 bytes) you can write to a file with name ending with ".cmd" to make it run on Windows. And for Linux you need just add execution rights:

{{< highlight bash >}}
chmod a+x ./myscript.cmd
{{< /highlight >}}

That's it. If you have you own examples of cross-platform scripts, I'd be glad to know about them.
