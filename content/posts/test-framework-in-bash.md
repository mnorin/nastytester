---
title: "Test Framework in Bash"
author: "Max Norin"
type: "post"
date: 2018-12-05T22:17:07+13:00
subtitle: "Quoting means just that, bracketing a string in quotes. (c) Advanced Bash-Scripting Guide"
image: ""
tags: [linux,bash,testing,framework]
draft: true
---

It's good to know how to test different things. What actually testing something is about? Prove me wrong, but it's mostly about discrepancies.
When you test something, you always know (or may think that you know) how something supposed to work.
And when you want to test a program that supposed to work on Linux, you may want to use bash even though it's not traditional to use it as a testing tool.

### Why

There are some reasons:

1. Most Linux-based operating systems have it, many of them by default.
2. You can do many interesting thing with only bash, even without using programs from linux-base package (including network-related operations, such as writing something directly to opened port on the remote computer).
3. It has very detailed manual and there is also ABS guide.
4. It may be very powerfull without writing much code.

There are also reasons not to use it:

1. It may be weird if you know some programming languages.
2. It may be complicated even if you have some experience.
3. Some people say it's hard to debug (well, it's may be not as straightforward as a debugger in your favorite IDE).
4. The most important thing: you can totally unleash its power only when you know Linux operating systems well (at least two of them, one Debian-based and one RedHat/CentOS-based).

Anyway, using bash may be the simplest thing you can use for certain things.

### What we can use for testing

Basically, everything that can be installed on your Linux system. But before using whatever you want to use, you need to understand what you are going to test and how you are going to test it.
Because many people can write scripts, but not all of them understand how to test.

One thing you can definitely consider useful is ability to retrieve an exit code from pretty much every program you can run. Usually exit code means something and you can check program's documentation (or man page) for this information.
When program finished working successfully, it should return exit code 0, if there was an error, then it should return appropriate exit code.

Bash allows to change the script workflow based on exit codes. For example, command "test" or command "[", these two basically check conditions, and return some exit code based on the comparison result.
If condition is true, they return 0, otherwise they return something else (doesn't really matter at this point).
Operator "if" uses the exit code from "[" or "test" to execute a set of commands, one of few sets of commands or none of them.

