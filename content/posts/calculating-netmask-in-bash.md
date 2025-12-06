---
title: "Calculating netmask in bash"
author: "Max Norin"
type: "post"
date: 2025-12-05T23:44:36+13:00
subtitle: "Masks were meant to be used for a reason and not to hide behind. (c) Anthony T. Hincks"
image: ""
tags: ["bash", "linux"]
draft: false
---

A subnet mask is a set of bits that determines how many bits are used to specify the subnet address and how many are used to specify the computer address within that subnet.
It's more common to see a subnet mask in decimal notation, but it's actually represented in binary.
If you understand how a subnet address and a computer address within that subnet are represented, you can easily determine the subnet address and subnet mask from the computer address and subnet mask, as follows:
{{< highlight bash >}}
<subnet-address>/<number-of-bits>
{{< /highlight >}}

## Subnet mask example

Let's say you have a network 192.168.1.0 (a class C network), and the subnet mask (netmask) is represented as 255.255.255.0 (in binary form, this is 11111111 11111111 11111111 00000000).
This means that the first 24 bits are allocated for the subnet address, and 8 bits are allocated for the computer address on the subnet.
That is, the range of values of the last octet (the last 8 bits) will take on 256 different values (values from 0 to 255 inclusive), where 0 is the subnet address, and 255 is the broadcast address.
So, you can allocate 254 addresses (from 1 to 254) for computer addresses. And, while on any computer running an operating system based on the Linux kernel, you can view the computer's address and network mask using the "ifconfig" and "ip addr" commands.

Sometimes, given a computer address and a subnet mask, it is necessary to determine the subnet address and the bit depth of the network mask in order to represent the subnet address in the form
{{< highlight bash >}}
<subnet-address>/<number-of-bits-in-mask>
{{< /highlight >}}

For example:
{{< highlight bash >}}
192.168.1.0/24
{{< /highlight >}}

Let's try to solve the problem of such a transformation in bash.

## Converting from decimal to binary in bash

To solve this problem, we need to convert the subnet mask to binary form, since a subnet mask (netmask) is a sequence of bits that determines which bits in a given address are allocated to the subnet address (the bit is set to 1)
and which are allocated to the computer address within the subnet. This is a crucial point in understanding IP addresses.

Bash doesn't have a function for converting decimal numbers to binary, so we'll need to use a little trick.
It involves generating an array of sequences of ones and zeros, each element of which is the binary representation of the decimal value of that element's index.

{{< highlight bash >}}
BINARRAY=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
{{< /highlight >}}

This string will be expanded into an array containing 8-bit values, which is equivalent to the following operations:

{{< highlight bash >}}
BINARRAY[0]="00000000"
BINARRAY[1]="00000001"
BINARRAY[2]="00000010"
... 
BINARRAY[254]="11111110"
BINARRAY[255]="11111111"
{{< /highlight >}}

## Converting from binary to decimal in bash

We need the inverse conversion to convert the bit sequence back to a decimal number. This is simpler.
Bash has the ability to convert a number from N-ary to decimal, where N is a number up to and including 64. Here's what it looks like for the base-2 (binary) number system:

{{< highlight bash >}}
$ A=$((2#00000010)) 
$ echo $A 
2 
$ B=$((2#11111110)) 
$ echo $B 
254
{{< /highlight >}}

As you can see, in this case everything is very simple.

## Let's write a script

{{< highlight bash >}}
#!/bin/bash

# This script converts IP address and netmask from a network interface (e.g. 192.168.1.123 255.255.255.0)
# to a network address (e.g. 192.168.1.0/24) in pure bash without external programs.

if [ -z "$1" ] || [ -z "$2" ]; then echo -e "Usage: $0 <IP> <long-mask>\nExample: $0 192.168.1.14 255.255.255.0"; exit 1; fi

BARRAY=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

BINARY_IP_ADDRESS=$(for octet in ${1//./ }; do echo -n ${BARRAY[octet]}; done)
BINARY_NETMASK=$(for octet in ${2//./ }; do echo -n ${BARRAY[octet]}; done)
BITS=${BINARY_NETMASK%%0*}
BITS_COUNT=${#BITS}

NETWORK_ADDRESS=${BINARY_IP_ADDRESS:0:BITS_COUNT}${BINARY_NETMASK:BITS_COUNT}

NEW_ADDRESS="${NETWORK_ADDRESS:0:8} ${NETWORK_ADDRESS:8:8} ${NETWORK_ADDRESS:16:8} ${NETWORK_ADDRESS:24:8}"

DECIMAL_ADDRESS=`echo $(for octet in $NEW_ADDRESS; do echo $((2#$octet)); done)`
DECIMAL_ADDRESS=${DECIMAL_ADDRESS// /.}

echo $DECIMAL_ADDRESS/$BITS_COUNT
{{< /highlight >}}

Here it is. This script doesn't use external programs, so should work everywhere where you have a relatively fresh bash version (because of all parameter expansions I used).

## Let's see if it works

{{< highlight bash >}}
$ echo $(ifconfig enp5s0 | grep netmask | awk '{print $2" "$4}')
192.168.0.2 255.255.255.0
$ ./network-conv.sh $(ifconfig enp5s0 | grep netmask | awk '{print $2" "$4}')
192.168.0.0/24
{{< /highlight >}}

Nice. Just what I needed.

Obviously, if you need, you can add format validation for IP address and netmask, or add a reverse conversion, in any case, you can do all of it in pure bash.
