# RealReachability
[![Version](https://img.shields.io/badge/pod-1.1-yellow.svg)](http://cocoadocs.org/docsets/RealReachability/1.1/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](http://cocoadocs.org/docsets/RealReachability/1.1/)
[![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)](http://cocoadocs.org/docsets/RealReachability/1.1/)
[![Platform](https://img.shields.io/badge/Build-Passed-green.svg)](http://cocoadocs.org/docsets/RealReachability/1.1/)
####We need to observe the REAL reachability of network for iOS. That's what RealReachability do.
#Why RealReachablity?
As we know, we already have reachablity framework for us to choose. Such as the famous repository [Reachability](https://github.com/tonymillion/Reachability).

**BUT we really need a tool for us to get the reachablity, not the local connection!**

**Apple doc tells us somthing about SCNetworkReachability API:
"Note that reachability does not guarantee that the data packet will actually be received by the host."**

The called "reachability" we already know can only tell us the local connection status.These tools current we know are all supported by the SCNetworkReachability API.


**Now [RealReachablity](https://github.com/dustturtle/RealReachability) can do this for you~**

We introduce ping module for us to check the real network status, together with SCNetworkReachability API. And we use FSM(finite state machine) to control all of the network status to confirm that only status change will be sent to application.

Enjoy it!

#Quick Start With Cocoapods
[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries like RealReachability in your projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

#### Podfile

To integrate RealReachability into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '6.0'

pod 'RealReachability', '~> 1.1'
```

Then, run the following command:

```bash
$ pod install
```

#Manual Start
If you'd rather do everything by hand, just add the folder "RealReachability" to your project, then all of the files will be added to your project.


# Dependencies

- Xcode 5.0+ for ARC support, automatic synthesis and compatibility
  libraries. iOS 6.0+.
- The SystemConfiguration Framework should be added to your project.

#Usage
####Start to notify:

```objective-c
    [GLobalRealReachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(networkChanged:)
                                                 name:kRealReachabilityChangedNotification
                                               object:nil];

```
####Observer like below:
```objective-c
- (void)networkChanged:(NSNotification *)notification
{
    RealReachability *reachability = (RealReachability *)notification.object;
    ReachabilityStatus status = [reachability currentReachabilityStatus];
    NSLog(@"currentStatus:%@",@(status));
}

```
####Trigger realtime Reachability like below:
```objective-c
[GLobalRealReachability reachabilityWithBlock:^(ReachabilityStatus status) {
        switch (status)
        {
            case NotReachable:
            {
            //  case NotReachable handler
                break;
            }
                
            case ReachableViaWiFi:
            {
            //  case ReachableViaWiFi handler
                break;
            }
                
            case ReachableViaWWAN:
            {
            //  case ReachableViaWWAN handler
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

#Demo
We already put the demo project in the [repository](https://github.com/dustturtle/RealReachability).

# License

RealReachability is released under the MIT license. See LICENSE for details.

## And finally...

Please use and improve! Patches accepted, or create an issue.

I'd love it if you could send me a note as to which app you're using it with! Thank you!

