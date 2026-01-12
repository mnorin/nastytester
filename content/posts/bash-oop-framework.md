---
title: "ba.sh: A minimal pattern for organising bash code"
author: "Max Norin"
type: "post"
date: 2026-01-12T21:48:36+13:00
subtitle: “Simplicity is the ultimate sophistication.” (c) Leonardo da Vinci
image: ""
tags: ["bash", "linux"]
draft: false
---

When you hear "bash OOP framework", what comes to mind?
Probably complexity, overhead, fighting the language.
But what if it didn't have to be that way?
If you've written bash scripts for any length of time, you know how it can go.
It starts simple: a few commands in a file. Then you add a function. Then another. Then some variables.
Before you know it, you have 500 lines of tangled code where everything can access everything, functions have names you don't remember, and you're scared to change anything because you don't know what might break.
[ba.sh](https://github.com/mnorin/ba.sh) is a tiny set of patterns for organizing bash code that I created back in 2013.
It's an object-oriented framework for bash. But not a framework in the traditional sense, it's just around 20 lines of pure bash that let you structure your code using objects and namespaces.
No dependencies, no installation, no magic. Just a way to keep your bash scripts from turning into spaghetti.

## What does it look like?

{{< highlight bash >}}
# Source the ba.sh constructor
. task.h

# Create a task object
task task1

# Set properties
task1.name = "Deploy application"
task1.priority = 5

# Call methods
task1.validate
task1.execute
{{< /highlight >}}

The syntax probably looks familiar, it's similar to Python or JavaScript.
But under the hood, it's just bash. The obj function reads your class definition and does simple string substitution to create namespaced functions.
When you write task1.execute, you're calling a regular bash function named task1.execute.
No runtime overhead, no interpretation layer, just plain bash functions.

The real power comes from how you define these classes. A class is just a bash file with a special naming convention:

{{< highlight bash >}}
# task.class
__OBJECT___properties=()

__OBJECT__.property(){
    # Property storage implementation. This can be customised per class.

    # Property indices (only needed if you use an indexed array as the storage.
    local name=0
    local priority=1
    if [ "$2" = "=" ]
    then
        __OBJECT___properties[$1]="$3"
    else
        echo ${__OBJECT___properties[$1]}
    fi
    # Check official documentation for more details.
    # ba.sh supports indexed arrays, associative arrays
    # as underlying storages, and that's not all.
}

__OBJECT__.name(){
    if [ "$1" = "=" ]
    then
        __OBJECT__.property name = "$2"
    else
        __OBJECT__.property name
    fi
}

__OBJECT__.priority(){
    if [ "$1" = "=" ]
    then
        __OBJECT__.property priority = "$2"
    else
        local value=$(__OBJECT__.property priority)
        echo ${value:-3} # Default priority
    fi
}

__OBJECT__.execute(){
    local name=$(__OBJECT__.property name)
    echo "Executing task: $name"
    # Your execution logic here
}

__OBJECT__.validate(){
    local priority=$(__OBJECT__.property priority)
    if [[ ! "$priority" =~ ^[1-5]$ ]]; then
        echo "Error: Priority must be 1-5" >&2
        return 1
    fi
}

{{< /highlight >}}

When you call "task task1", ba.sh reads task.class, replaces every instance of "`__OBJECT__`" with "`task1`", and sources the result.
That's it. The pattern "`__OBJECT__`" becomes "`task1`", so "`__OBJECT__.execute`" becomes "`task1.execute`".
Simple string substitution, and now you have a namespaced set of functions and a namespaced array to keep your property values.

## Property validation

Property validation happens right where you expect it. Instead of a type system that fights bash's string-based nature, you validate property values in your property setters:

{{< highlight bash >}}
__OBJECT__.priority(){
    if [ "$1" = "=" ]; then
        # Setting the property
        if [[ ! "$2" =~ ^[1-5]$ ]]; then
            echo "Error: Priority must be 1-5" >&2
            return 1
        fi
        __OBJECT__.property priority = "$2"
    else
        # Getting the property
        __OBJECT__.property priority
    fi
}
{{< /highlight >}}

Now `task1.priority = 5` validates that the value is between 1 and 5, but only when you set it.
No runtime type checking on every access, no global type registry, just validation where and when (if) you need it.

## Composition

Composition is straightforward because it's just bash. Want a task that also has logging capabilities? Just call both constructors:

{{< highlight bash >}}
# Create object with multiple behaviors
task task1
logger task1

# Now task1 has both task methods and logger methods
task1.name = "Deploy"
task1.log "Starting deployment"
task1.execute
{{< /highlight >}}

## Inheritance

The inheritance pattern is equally simple. If you want a child class to inherit from a parent, the first line of your child class just calls the parent constructor:

{{< highlight bash >}}
# scheduledTask.class
task __OBJECT__  # Inherit from task

__OBJECT__.schedule(){
    local time="$1"
    echo "Scheduling at $time"
    # Scheduling logic
}
{{< /highlight >}}

When you create a scheduled task, it gets all the methods from the task class plus its own scheduling methods.
No complex inheritance hierarchies, no method resolution order, just functions building on functions.
ba.sh doesn't need a version 2.0 because it does exactly what it needs to do: provide a simple pattern for organizing bash code.
It doesn't try to add types to a typeless language, doesn't fight bash's nature, doesn't create complexity.
It's just a pattern - string substitution to create namespaces - and that's why it still works perfectly over a decade later.
If your bash scripts are getting messy and you want a simple way to organize them without learning a complex framework or fighting the language,
ba.sh might be what you need.

It's just bash, organized.

Check it out at [github.com/mnorin/ba.sh](https://github.com/mnorin/ba.sh). There are more possibilities and more documentation.

