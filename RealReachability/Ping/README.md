# SimplePing by apple(That is where PingFoundation modified from!!!Many Thanks to APPLE!)

1.4

SimplePing demonstrates ping (ICMP) send and receive.

## Requirements

### Build

Xcode 7.3

The sample was built using Xcode 7.2.1 on OS X 10.11.2 with the OS X 10.11 SDK.  You should be able to just open the project, select the *MacTool* scheme, and choose *Product* > *Build*.

### Runtime

10.11

Although the sample requires 10.11, the core code works just fine on all versions of iOS and the underlying approach works on earlier versions of OS X (back to 10.2).

## Packing List

The sample contains the following items:

* `README.md` — This file.

* `LICENSE.txt` — The standard sample code license.

* `SimplePing.xcodeproj` — An Xcode project for the program.

* `Common` — A directory containing common code, namely, the SimplePing class, an object wrapper around the low-level BSD Sockets ping function.

* `MacTool` — A directory containing a single file, `main.m`, which is a Mac command line tool to exercise the SimplePing class.

* `iOSApp` — A directory containing a trivial iOS app to test the SimplePing class.  Most of it is boilerplate; the only interesting code is in `MainViewController.swift`, which is the iOS analogue of `main.m`.

## Using the Sample

Once you’ve built the SimplePing tool you can test it by running it from Terminal with the address of a host to ping.  For example:

    $ ./SimplePing www.apple.com
    2016-02-29 10:28:03.589 SimplePing[58314:6905268] pinging 23.53.214.138
    2016-02-29 10:28:03.590 SimplePing[58314:6905268] #0 sent
    2016-02-29 10:28:03.626 SimplePing[58314:6905268] #0 received, size=64
    2016-02-29 10:28:04.592 SimplePing[58314:6905268] #1 sent
    2016-02-29 10:28:04.630 SimplePing[58314:6905268] #1 received, size=64
    ^C

The program will keep pinging until you stop it with ^C.

## How it Works

On most platforms ping requires privileges (it’s implemented with a raw IP socket).  Apple platforms include a special facility that allows you to ping without privileges.  Specifically, you can open a special, non-privileged ICMP socket that allows you to send and receive pings.  Look at the `-[SimplePing startWithHostAddress]` method for the details.

Beyond that, SimplePing is a very simply application of CFHost (for name-to-address resolution) and CFSocket (for integrating the ICMP socket into the runloop).

## Using the SimplePing Class

To use the SimplePing class in your app, add `SimplePing.h` and `SimplePing.m` to your project.

**Note** If you’re developing solely in Swift, Xcode will prompt you as to whether you want to create a bridging header or not.  Agree to that by clicking Create Bridging Header.

If you want to call SimplePing from your Swift code, add the following line to your bridging header.

    #include "SimplePing.h"

Alternatively, if you’re using Objective-C, add the same line at the start of your `.m` file.

Finally, to use the SimplePing class:

1. create an instance of the SimplePing class and keep a reference to that instance

2. set the `delegate` property

3. call `start()`.

4. if things go well, your delegate’s `simplePing(_:didStartWithAddress:)` method will be called; to send a ping, call `sendPingWithData(_:)`

5. when SimplePing receives an ICMP packet, it will call the `simplePing(_:didReceivePingResponsePacket:sequenceNumber:)` or `simplePing(:didReceiveUnexpectedPacket:)` delegate method

SimplePing can be used from any thread but the use of any single instance must be confined to a specific thread.  Moreover, that thread must run its run loop.  In most cases it’s best to use SimplePing from the main thread.

The SimplePing class has lots of header docs that explain it’s features in more depth.  And if you’re looking for an example, there’s both Objective-C (`MacTool/main.m`) and Swift (`iOSApp/MainViewController.swift`) ones available.

## Caveats

Much of what SimplePing does with CFSocket can also be done with GCD.  Specifically, GCD makes it easy to integrate a BSD Socket into a typical run loop based program.  This sample uses CFSocket because a) there are other examples of using GCD for socket-based networking, b) there are cases where CFSocket has advantages over GCD (for example, if you want to target a specific run loop, or a specific run loop mode), and c) at the time the sample was originally created, CFSocket was more commonly used.

## Feedback

If you find any problems with this sample, or you’d like to suggest improvements, please [file a bug][bug] against it.

[bug]: <http://developer.apple.com/bugreporter/>

## Version History

1.0.1 (Oct 2003) was the first shipping version.

1.1 (Feb 2010) was a complete rewrite with the twin goals of tidying the code and making the core code portable to iOS.

1.2 (Mar 2010) fixed a trivial problem that was causing the SimplePing module to not compile for iOS out of the box.

1.3 (Jul 2012) was a minor update to adopt the latest tools and techniques (most notably, ARC).

1.4 (Feb 2016) added support for IPv6.  There were many other editorial changes that don’t don’t impact on the core functionality of the sample.

Share and Enjoy

Apple Developer Technical Support<br>
Core OS/Hardware

18 Apr 2016

Copyright (C) 2016 Apple Inc. All rights reserved.
