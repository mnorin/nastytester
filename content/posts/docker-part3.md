---
title: "Docker: Stop using it the wrong way. Part 3."
author: "Max Norin"
type: "post"
subtitle: "If this is a coffee, please bring me some tea; but if this is tea then please bring me some coffee (c) Abraham Lincoln"
image: ""
tags: ["docker", "linux", "java"]
date: 2019-03-10T18:09:28+13:00
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

So, we want to install Java 11 and build our app.

Dockerfile:

{{< highlight docker >}}
FROM debian:stretch-slim

RUN apt-get update 
 && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends \
 curl ca-certificates krb5-locales libcurl3 libffi6 libgmp10 libgnutls30 \
 libgssapi-krb5-2 libhogweed4 libidn11 libidn2-0 libk5crypto3 libkeyutils1 \
 libkrb5-3 libkrb5support0 libldap-2.4-2 libldap-common libnettle6 \
 libnghttp2-14 libp11-kit0 libpsl5 librtmp1 libsasl2-2 libsasl2-modules \
 libsasl2-modules-db libssh2-1 libssl1.0.2 libssl1.1 libtasn1-6 libunistring0 \
 openssl publicsuffix libasound2 libasound2-data \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists \
 && curl -L -b "oraclelicense=a" -O http://download.oracle.com/otn-pub/java/jdk/11.0.2+9/f51449fcd52f4d52b93a989c5c56ed3c/jdk-11.0.2_linux-x64_bin.deb \
 && dpkg -i ./jdk-11.0.2_linux-x64_bin.deb \
 && rm ./jdk-11.0.2_linux-x64_bin.deb \
 && echo 'public class Hello{public static void main(String[] argv){System.out.println("Hello world!");}}' > Hello.java \
 && mkdir META-INF \
 && echo 'Main-Class: Hello' > META-INF/MANIFEST.MF \
 && JAVA_HOME=/usr/lib/jvm/jdk-11.0.2 \
 && PATH=$PATH:/${JAVA_HOME}/bin \
 && javac Hello.java \
 && jar cvmf META-INF/MANIFEST.MF Hello.jar Hello.class \
 && rm -rf META-INF Hello.class

CMD ["/usr/lib/jvm/jdk-11.0.2/bin/java","-jar","Hello.jar"]
{{< /highlight >}}

We build it using command

{{< highlight bash >}}
docker build -t local/java11-app .
{{< /highlight >}}

We receive a container image with the size of 378 MB:

{{< highlight bash >}}
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
local/java11-app    latest              8af86d0c908d        2 minutes ago       378MB
{{< /highlight >}}

And if we run it:

{{< highlight bash >}}
$ docker run local/java11-app
Hello world!
{{< /highlight >}}

Our app works, it actually does what it should, but this container image is bigger than I would like it to be.
Because we have the whole Java runtime even though we don't use most of it.

Now we can build our custom runtime and then create the final version of this container image.

I'll skip some details as I already described them in part 2, and I'll just show you what we get in the end.

{{< highlight docker >}}
FROM debian:stretch-slim as builder

# Install all necessary packages
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends \
 curl ca-certificates krb5-locales libcurl3 libffi6 libgmp10 libgnutls30 \
 libgssapi-krb5-2 libhogweed4 libidn11 libidn2-0 libk5crypto3 libkeyutils1 \
 libkrb5-3 libkrb5support0 libldap-2.4-2 libldap-common libnettle6 \
 libnghttp2-14 libp11-kit0 libpsl5 librtmp1 libsasl2-2 libsasl2-modules \
 libsasl2-modules-db libssh2-1 libssl1.0.2 libssl1.1 libtasn1-6 libunistring0 \
 openssl publicsuffix libasound2 libasound2-data \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists

# Install JDK 11
RUN curl -L -b "oraclelicense=a" -O http://download.oracle.com/otn-pub/java/jdk/11.0.2+9/f51449fcd52f4d52b93a989c5c56ed3c/jdk-11.0.2_linux-x64_bin.deb \
 && dpkg -i ./jdk-11.0.2_linux-x64_bin.deb \
 && rm ./jdk-11.0.2_linux-x64_bin.deb

ENV JAVA_HOME "/usr/lib/jvm/jdk-11.0.2"

# Create and compile a program
RUN echo 'public class Hello{public static void main(String[] argv){System.out.println("Hello world!");}}' > Hello.java \
 && mkdir META-INF \
 && echo 'Main-Class: Hello' > META-INF/MANIFEST.MF \
 && PATH=$PATH:/${JAVA_HOME}/bin \
 && javac Hello.java \
 && jar cvmf META-INF/MANIFEST.MF Hello.jar Hello.class

# Build minimized runtime
RUN JAVA_MODULES=$(${JAVA_HOME}/bin/jdeps Hello.jar | awk '{print $4}' | grep -v '^$' | sort | uniq) &&\
 JAVA_MODULES=$(echo $JAVA_MODULES | sed -e 's/ /,/g') &&\
 ${JAVA_HOME}/bin/jlink --no-header-files --no-man-pages --output /jdk11 --compress 2 --add-modules ${JAVA_MODULES}

# At his point we have /jdk11 and /Hello.jar built
# So we can start creating the final image

FROM scratch as runner

COPY --from=builder /jdk11 /jdk11
COPY --from=builder /Hello.jar /Hello.jar
COPY --from=builder /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
COPY --from=builder /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
COPY --from=builder /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0
COPY --from=builder /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
COPY --from=builder /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
COPY --from=builder /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6
COPY --from=builder /lib/x86_64-linux-gnu/librt.so.1 /lib/x86_64-linux-gnu/librt.so.1

ENV JAVA_HOME /jdk11

CMD ["/jdk11/bin/java","-jar","Hello.jar"]
{{< /highlight >}}

Now we build the image:

{{< highlight bash >}}
docker build -t local/java11-app .
{{< /highlight >}}

And run it:

{{< highlight bash >}}
docker run local/java11-app
{{< /highlight >}}

As the run result we get "Hello world!" printed.
And now we can check how big is the image:

{{< highlight bash >}}
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
local/java11-app    latest              eaae6f01c109        4 minutes ago       39.2MB
<none>              <none>              2e3144e88cb7        17 minutes ago      414MB
{{< /highlight >}}

As you can see, first image, named "builder" is 414MB big, but the second one, named "runner", is only 39.2MB.
Making it even smaller may be really challenging, so, we should stop at this point and enjoy the result.
