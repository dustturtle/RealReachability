# RealReachability
[![Version](https://img.shields.io/badge/pod-1.3.0-yellow.svg)](http://cocoadocs.org/docsets/RealReachability/1.3.0/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](http://cocoadocs.org/docsets/RealReachability/1.3.0)
[![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)](http://cocoadocs.org/docsets/RealReachability/1.3.0/)
[![Platform](https://img.shields.io/badge/Build-Passed-green.svg)](http://cocoadocs.org/docsets/RealReachability/1.3.0/)
#### We need to observe the REAL reachability of network for iOS. That's what RealReachability do.

# Why RealReachability?
As we know, we already have reachability framework for us to choose. Such as the famous repository [Reachability](https://github.com/tonymillion/Reachability).

**BUT we really need a tool for us to get the reachability, not the local connection!**

**Apple doc tells us something about SCNetworkReachability API:
"Note that reachability does not guarantee that the data packet will actually be received by the host."**

The called "reachability" we already know can only tell us the local connection status.These tools currently we know are all supported by the SCNetworkReachability API.


**Now [RealReachability](https://github.com/dustturtle/RealReachability) can do this for you~**

We introduce ping module for us to check the real network status, together with SCNetworkReachability API. And we use FSM(finite state machine) to control all of the network status to confirm that only status change will be sent to application.

Enjoy it!

# Quick Start With Cocoapods
[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like RealReachability in your projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

#### Podfile

To integrate RealReachability into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

pod 'RealReachability'
```

Then, run the following command:

```bash
$ pod install
```
# Installation with Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

RealReachability in your `Cartfile`:

```
github "dustturtle/RealReachability"
```

# Manual Start
If you'd rather do everything by hand, just add the folder "RealReachability" to your project, then all of the files will be added to your project.


# Dependencies

- Xcode 5.0+ for ARC support, automatic synthesis and compatibility
  libraries. iOS 6.0+.
- The SystemConfiguration Framework should be added to your project.

# Usage
#### Start to notify(we suggest you to start notify in didFinishLaunchingWithOptions):

```objective-c

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GLobalRealReachability startNotifier];
    return YES;
}
```
#### Add Observer(anywhere you like):
```objective-c
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(networkChanged:)
                                             name:kRealReachabilityChangedNotification
                                           object:nil];

```

#### Observer method like below:
```objective-c
- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *reachability = (RealReachability *)notification.object;
    ReachabilityStatus status = [reachability currentReachabilityStatus];
    NSLog(@"currentStatus:%@",@(status));
}

```
#### Trigger realtime Reachability like below:
```objective-c
[GLobalRealReachability reachabilityWithBlock:^(ReachabilityStatus status) {
        switch (status)
        {
            case RealStatusNotReachable:
            {
            //  case NotReachable handler
                break;
            }
                
            case RealStatusViaWiFi:
            {
            //  case WiFi handler
                break;
            }
                
            case RealStatusViaWWAN:
            {
            //  case WWAN handler
                break;
            }
                
            default:
                break;
        }
    }];
```
#### Query currentStatus
```
ReachabilityStatus status = [reachability currentReachabilityStatus];
```

Once the reachabilityWithBlock was called, the "currentReachabilityStatus" will be refreshed synchronously.
#### Set your own host for Ping (optional)
##### Note that now we introduced the new feature "doublecheck" to make the status more reliable in 1.2.0!
Please make sure the host you set here is available for pinging. Large, stable website suggested.   
This step is optional. If you do not set this, our default host is: www.apple.com.   
You may set your own host any time you like. Codes just like below:

```
GLobalRealReachability.hostForPing = @"www.apple.com";
GLobalRealReachability.hostForCheck = @"www.youOwnHostExample.com";
```
We suggest you use two hosts: one your own(if you have one available for pinging), one public; Just like the example below.

For more details about the "doublecheck" feature, you can go deep into the codes.

#### Get current WWAN type (optional)
```
 WWANAccessType accessType = [GLobalRealReachability currentWWANtype];

```
Current WWAN type might be used to improve your app's user experience(e.g, set different network request timeout interval for different WWAN type).
#### Check the VPN status of your network
```
- (BOOL)isVPNOn;
```
With the help of this method, we have improved our reachability check logic when using VPN.
#### More:
We can also use PingHelper or LocalConnection alone to make a ping action or just observe the local connection.  
Pod usage like blow (we have two pod subspecs):

```ruby
pod 'RealReachability/Ping'
```
```ruby
pod 'RealReachability/Connection'
```
This is the only API we need to invoke about Ping:

```objective-c
- (void)pingWithBlock:(void (^)(BOOL isSuccess))completion;

```
**More about the ping usage**, please see the **PingHelper.h** or codes in [**the demo project**](https://github.com/dustturtle/RealReachability).

**LocalConnection module is very similar with Reachability**.   
**More about its usage**, please see the **LocalConnection.h** or codes in [**the demo project**](https://github.com/dustturtle/RealReachability). 


# Demo
We already put the demo project in the [repository](https://github.com/dustturtle/RealReachability).

# License

RealReachability is released under the MIT license. See LICENSE for details.

## And finally...

Please use and improve! Patches accepted, or create an issue.

I'd love it if you could send me a note as to which app you're using it with! Thank you!

## [中文版使用指南](http://blog.csdn.net/openglnewbee/article/details/50705146)

