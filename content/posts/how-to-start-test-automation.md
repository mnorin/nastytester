---
title: "How to start test automation"
author: "Max Norin"
type: "post"
date: 2018-12-05T22:17:07+13:00
subtitle: "The secret to getting ahead is getting started. (c) Mark Twain"
image: ""
tags: [testing,test automation,framework]
draft: true
---

For some reason the topic I'm going to write about is something that many people are not familiar with, even though they write test automation scripts for a while.
In many cases people came to a company when someone've already started integrating test scripts (or test scenarios) and they just write test scripts for a certain test framework.
For this reason when it comes to starting from scratch, they just don't see the whole picture.

For know, let's skip starting automation when you never automated anything, we'll talk about it later. Let's assume, you know how to write test scripts in any programming language, but you don't know
how to set up the whole process.

### What to do when you don't know how to start

First of all, DON'T PANIC!

Yes, the situation is somewhat unpleasant, but trust me, there is nothing to be scared about. If you have experience automating tests you already know someting. It may be not much, but it's a piece of a puzzle, and something you can already use.
All you need to do is to collect all the pieces and put them all in right places. Let's just look at them without any specific details. So, what are those pieces?

0) How good are you in testing?
1) What do you want to automate?
2) What programming language do you know?
3) Can you build a package or an app written in this programing language?
4) What testing framework for your programming language you are familiar with?
5) Are you going to start with API or Selenium tests? (I was thinking about UI tests, but for our time most likely it will be some web application)
6) If it's web application, what browsers are you going to support?
7) How and where would you like to run your tests?
8) What do you want you reports to look like?

And now to details.

### How good are you in testing?

Number "zero" of everything related to test automation. How so? It's the base you need to understand first. If you are not a good tester, then it doesn't matter if you can automate anything.
Because the result we want to achieve is to actually test something. In other words, we need to be able to get the current state of a software product, and if you can't do it manually, then nothing will help you to do it automatically.
If you know how to test and you are good at it, then you will understand how to actually write test scripts, otherwise you can write a script that does not really test anything. And it will be just a waist of your time and your employer's money.

If you don't feel like you are good in testing, make sure you work on it and may be it makes sense to postpone test automation for now.

### What do you want to automate?

First answer many people think about is "I want to automate tests". I wouldn't say they are wrong, but, come on, what tests? Why do you want to automate them? You need a wider look.
And more interesting answer is "I want to automate functional tests to prevent regressions in new builds".
But actually in terms of Agile it would be a user story "As a tester I want to automate functional tests, so I could decrease regressions, make regression tests faster, exclude a human factor, 
and make it possible to understand the current state of the product in a as short amount of time as possible".
This is much closer to the point. What else could it be? For example, "As a tester I want to automate API tests so I could check multiple combinations of parameters for requests to every endpoint we have, exclude a human factor, 
be able to run these tests every time we get a new build in a short time, and make it easier for everyone to run API tests on demand when needed."

Just take your time, write your user story and it will be the outline of the work you will need to do to get to the goal.

### What programming language do you know?

Oh, yeah. This is an interesting question. If you think of some specific programming language and nothing else, try to look around it. So, what are you supposed to see? A lot of details, such as:
- Operating system you can run programs written in this programming language on
- Compilers and/or builders you plan to use (you may need to learn different compiler/builder parameters if you want to build your frameworks)
- How easy it will be for juniors to start using this language

A good example: I want to write test scripts in Java, because it supports different operating systems, so I can write tests on Windows, run then on Linux-based Jenkins CI server, use maven to build packages, 
and it's relatively easy to start with for juniors as Java is pretty popular. I also know C#, but I don't want to use it, because in this case it may be harder to use operating systems different from Windows.

### Can you build a package or an app written in this language?


