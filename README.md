# RealReachability
[![Version](https://img.shields.io/badge/pod-1.1.5-yellow.svg)](http://cocoadocs.org/docsets/RealReachability/1.1.5/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](http://cocoadocs.org/docsets/RealReachability/1.1.5/)
[![Platform](https://img.shields.io/badge/Platform-iOS-orange.svg)](http://cocoadocs.org/docsets/RealReachability/1.1.5/)
[![Platform](https://img.shields.io/badge/Build-Passed-green.svg)](http://cocoadocs.org/docsets/RealReachability/1.1.5/)
####We need to observe the REAL reachability of network for iOS. That's what RealReachability do.


#####[NEWS FROM APPLE](https://developer.apple.com/news/?id=05042016a): Starting June 1, 2016 all apps submitted to the App Store MUST support IPv6-only networking.
### RealReachability SUPPORT IPV6 NOW. PLEASE UPDATE TO THE LATEST MASTER VERSION.
###Found any issue around IPV6, contact me as soon as possible, Thank you!
#Why RealReachability?
As we know, we already have reachability framework for us to choose. Such as the famous repository [Reachability](https://github.com/tonymillion/Reachability).

**BUT we really need a tool for us to get the reachability, not the local connection!**

**Apple doc tells us something about SCNetworkReachability API:
"Note that reachability does not guarantee that the data packet will actually be received by the host."**

The called "reachability" we already know can only tell us the local connection status.These tools currently we know are all supported by the SCNetworkReachability API.


**Now [RealReachability](https://github.com/dustturtle/RealReachability) can do this for you~**

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

pod 'RealReachability'
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
####Start to notify(we suggest you to start notify in didFinishLaunchingWithOptions):

```objective-c

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GLobalRealReachability startNotifier];
    return YES;
}
```
####Add Observer(anywhere you like):
```objective-c
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(networkChanged:)
                                             name:kRealReachabilityChangedNotification
                                           object:nil];

```

####Observer method like below:
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
Please make sure the host you set here is available for pinging. Large, stable website suggested.   
This step is optional. If you do not set this, our default host is: www.apple.com.   
You may set your own host any time you like. Codes just like below:
```
GLobalRealReachability.hostForPing = @"www.apple.com";
```

#### Get current WWAN type (optional)
```
 WWANAccessType accessType = [GLobalRealReachability currentWWANtype];

```
Current WWAN type might be used to improve your app's user experience(e.g, set different network request timeout interval for different WWAN type).

#Demo
We already put the demo project in the [repository](https://github.com/dustturtle/RealReachability).

# License

RealReachability is released under the MIT license. See LICENSE for details.

## And finally...

Please use and improve! Patches accepted, or create an issue.

I'd love it if you could send me a note as to which app you're using it with! Thank you!

##[中文版使用指南](http://blog.csdn.net/openglnewbee/article/details/50705146)

