//
//  RealReachability.h
//  Version 1.3.0
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#define GLobalRealReachability [RealReachability sharedInstance]

///This notification was called only when reachability really changed;
///We use FSM to promise this for you;
///We post self to this notification, then you can invoke currentReachabilityStatus method to fetch current status.
extern NSString *const kRealReachabilityChangedNotification;

extern NSString *const kRRVPNStatusChangedNotification;

typedef NS_ENUM(NSInteger, ReachabilityStatus) {
    ///Direct match with Apple networkStatus, just a force type convert.
    RealStatusUnknown = -1,
    RealStatusNotReachable = 0,
    RealStatusViaWWAN = 1,
    RealStatusViaWiFi = 2
};

typedef NS_ENUM(NSInteger, WWANAccessType) {
    WWANTypeUnknown = -1, /// maybe iOS6
    WWANType4G = 0,
    WWANType3G = 1,
    WWANType2G = 3
};

@protocol RealReachabilityDelegate <NSObject>
@optional
/// TODO:通过挂载一个定制的代理请求来检查网络，需要用户自己实现，我们会给出一个示例。
/// 可以通过这种方式规避解决http可用但icmp被阻止的场景下框架判断不正确的问题。
/// (Update: 已经添加了判断VPN的相关逻辑，以解决这种场景下大概率误判的问题)
/// 此方法阻塞？同步返回？还是异步？如果阻塞主线程超过n秒是不行的。
/// 当CustomAgent的doubleCheck被启用时，ping的doubleCheck将不再工作。
/// TODO: We introduce a custom agent to check the network by making http request, that need
/// the user to achieve this.
/// We want to solve the issue on special case(http available but icmp prevented).
/// NOTE: When the double check of the custom agent was used, the double check by ping will work no longer.
- (BOOL)doubleCheckByCustomAgent;
@end

@interface RealReachability : NSObject

/// Please make sure this host is available for pinging! default host:www.apple.com
@property (nonatomic, copy) NSString *hostForPing;

@property (nonatomic, copy) NSString *hostForCheck;

/// Interval in minutes; default is 2.0f, suggest value from 0.3f to 60.0f;
/// If exceeded, the value will be reset to 0.3f or 60.0f (the closer one).
@property (nonatomic, assign) float autoCheckInterval;

// Timeout used for ping. Default is 2 seconds
@property (nonatomic, assign) NSTimeInterval pingTimeout;

+ (instancetype)sharedInstance;

- (void)startNotifier;

- (void)stopNotifier;

/**
 *  To get real reachability we need to do async request,
 *  then we use the block blow for invoker to handle business request(need real reachability).
 *  Now we have introduced a double check to make our result more reliable.
 *
 *  @param asyncHandler async request handler, return in 5 seconds(max limit).
 *  The limit time may be adjusted later for better experience.
 */
- (void)reachabilityWithBlock:(void (^)(ReachabilityStatus status))asyncHandler;

/**
 *  Return current reachability immediately.
 *
 *  @return see enum LocalConnectionStatus
 */
- (ReachabilityStatus)currentReachabilityStatus;

/**
 *  Return previous reachability status.
 *
 *  @return see enum LocalConnectionStatus
 */
- (ReachabilityStatus)previousReachabilityStatus;

/**
 *  Return current WWAN type immediately.
 *
 *  @return unknown/4g/3g/2g.
 *
 *  This method can be used to improve app's further network performance
 *  (different strategies for different WWAN types).
 */
- (WWANAccessType)currentWWANtype;

/**
 *  Sometimes people use VPN on the device.
 *  In this situation we need to ignore the ping error.
 *  (VPN usually do not support ICMP.)
 *
 *  @return current VPN status: YES->ON, NO->OFF.
 *
 *  This method can be used to improve app's further network performance
 *  (different strategies for different WWAN types).
 */
- (BOOL)isVPNOn;

@end
