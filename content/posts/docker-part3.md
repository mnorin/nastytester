---
title: "Docker: Stop using it the wrong way. Part 3."
author: "Max Norin"
type: "post"
subtitle: "If this is a coffee, please bring me some tea; but if this is tea then please bring me some coffee (c) Abraham Lincoln"
image: ""
tags: ["docker", "linux", "java"]
date: 2018-11-20T22:00:07+13:00
draft: false
---

That's right! It's time to look at how to build a Docker container for a Java application.

As you know, programs written in Java are compiled to byte-code which is translated by Java Virtual Machine (JVM). To make it possible to run some small application written in Java you have to have the whole Java runtime environment.
Let's create a Docker container with Java 8 and look at how we can actually reduce its size. After that we'll see why Java 11 is better (only in this particular aspect, we are not going to discuss new language features like Optional, var, etc.).
Let it be an image based on Debian 9 ("Stretch") + OpenJDK 8 from official Debian repository + our small Java "Hello world!" app. We are not going to make any optimizations, we'll just look at what we get and what is wrong with it.

### Let's start

First, create a file named "Dockerfile" and write in this text:

{{< highlight docker >}}
FROM debian:latest

RUN apt-get update &&\
  apt-get -y install openjdk-8-jdk &&\
  echo 'public class Hello{public static void main(String[] argv){System.out.println("Hello world!");}}' > Hello.java &&\
  mkdir META-INF &&\
  echo 'Main-Class: Hello' > META-INF/MANIFEST.MF &&\
  javac Hello.java &&\
  jar cvmf META-INF/MANIFEST.MF Hello.jar Hello.class &&\
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/* &&\
  rm -rf META-INF Hello.java Hello.class

CMD ["java","-jar","Hello.jar"]
{{< /highlight >}}

Now let's build an image using this command:

    docker build -t local/java8-app .

And now look what have you done!

    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    local/java8-app     latest              0ab4d7be57ac        26 seconds ago      580MB

580 megabytes in total for a program that just prints "Hello world!". Yes, it's so big. No, it's not some kind of a joke. It's a total overhead, we need to do something with it.

### Changing Java version

It makes sense to upgrade to Java 11 (OpenJDK 11), as it supports creating modular runtime, in other words, you can create your own JRE that includes only modules your app supposed to use, so as a result you get a smaller runtime.
Frankly speaking, creating multiple Java applications containers is an overhead anyway, if you look into details, but containers are perfect if we want to simplify applications upgrade, and migrate application from Java 8 to Java 11 one by one, for example.
And if we put only modules certain application uses in each container, these containers should consume less resources.

There are couple of things you will need to use, that are parts of OpenJDK 11: jdeps and jlink. First one (jdeps) checks Java package dependencies, second one (jlink) compiles custom Java runtime.

So, we want to install OpenJDK 11 and build our app:

{{< highlight docker >}}
FROM debian:latest

RUN apt-get update &&\
  apt-get -y install openjdk-8-jdk &&\
  echo 'public class Hello{public static void main(String[] argv){System.out.println("Hello world!");}}' > Hello.java &&\
  mkdir META-INF &&\
  echo 'Main-Class: Hello' > META-INF/MANIFEST.MF &&\
  javac Hello.java &&\
  jar cvmf META-INF/MANIFEST.MF Hello.jar Hello.class &&\
  apt-get clean &&\
  rm -rf /var/lib/apt/lists/* &&\
  rm -rf META-INF Hello.java Hello.class

CMD ["java","-jar","Hello.jar"]
{{< /highlight >}}

