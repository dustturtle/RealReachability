//
//  RealReachability.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "RealReachability.h"
#import "FSMEngine.h"
#import "LocalConnection.h"
#import "PingHelper.h"
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

#if (!defined(DEBUG))
#define NSLog(...)
#endif

#define kDefaultHost @"www.baidu.com"
#define kDefaultCheckInterval 2.0f

NSString *const kRealReachabilityChangedNotification = @"kRealReachabilityChangedNotification";

@interface RealReachability()
@property (nonatomic, strong) FSMEngine *engine;
@property (nonatomic, assign) BOOL isNotifying;

@property (nonatomic,strong) NSArray *typeStrings4G;
@property (nonatomic,strong) NSArray *typeStrings3G;
@property (nonatomic,strong) NSArray *typeStrings2G;
@end

@implementation RealReachability

#pragma mark - Life Circle

- (id)init
{
    if ((self = [super init]))
    {
        _engine = [[FSMEngine alloc] init];
        [_engine start];
        
        _typeStrings2G = @[CTRadioAccessTechnologyEdge,
                           CTRadioAccessTechnologyGPRS,
                           CTRadioAccessTechnologyCDMA1x];
        
        _typeStrings3G = @[CTRadioAccessTechnologyHSDPA,
                           CTRadioAccessTechnologyWCDMA,
                           CTRadioAccessTechnologyHSUPA,
                           CTRadioAccessTechnologyCDMAEVDORev0,
                           CTRadioAccessTechnologyCDMAEVDORevA,
                           CTRadioAccessTechnologyCDMAEVDORevB,
                           CTRadioAccessTechnologyeHRPD];
        
        _typeStrings4G = @[CTRadioAccessTechnologyLTE];
        
        _hostForPing = kDefaultHost;
        _autoCheckInterval = kDefaultCheckInterval;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.engine = nil;
    
    [GLocalConnection stopNotifier];
}

#pragma mark - Handle system event

- (void)appBecomeActive
{
    if (self.isNotifying)
    {
        [self reachabilityWithBlock:nil];
    }
}

#pragma mark - Singlton Method

+ (instancetype)sharedInstance
{
    static id localConnection = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localConnection = [[self alloc] init];
    });
    
    return localConnection;
}

#pragma mark - actions

- (void)startNotifier
{
    if (self.isNotifying)
    {
        // avoid duplicate action
        return;
    }
    
    self.isNotifying = YES;
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLoad)};
    [self.engine receiveInput:inputDic];
    
    [GLocalConnection startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localConnectionChanged:)
                                                 name:kLocalConnectionChangedNotification
                                               object:nil];
    
    GPingHelper.host = _hostForPing;
    [self autoCheckReachability];
}

- (void)stopNotifier
{
    NSDictionary *inputDic = @{kEventKeyID:@(RREventUnLoad)};
    [self.engine receiveInput:inputDic];
    
    [GLocalConnection stopNotifier];
    
    self.isNotifying = NO;
}

#pragma mark - outside invoke

- (void)reachabilityWithBlock:(void (^)(ReachabilityStatus))asyncHandler
{
    // logic optimization: no need to ping when Local connection unavailable!
    if ([GLocalConnection currentLocalConnectionStatus] == LC_UnReachable)
    {
        if (asyncHandler != nil)
        {
            asyncHandler(RealStatusNotReachable);
        }
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    [GPingHelper pingWithBlock:^(BOOL isSuccess)
     {
         __strong __typeof(weakSelf)strongSelf = weakSelf;
         NSDictionary *inputDic = @{kEventKeyID:@(RREventPingCallback), kEventKeyParam:@(isSuccess)};
         NSInteger rtn = [strongSelf.engine receiveInput:inputDic];
         if (rtn == 0) // state changed & state available, post notification.
         {
             if ([self.engine isCurrentStateAvailable])
             {
                 // this makes sure the change notification happens on the MAIN THREAD
                 dispatch_async(dispatch_get_main_queue(), ^{
                     [[NSNotificationCenter defaultCenter] postNotificationName:kRealReachabilityChangedNotification
                                                                         object:self];
                 });
             }
         }
         
         if (asyncHandler != nil)
         {
             RRStateID currentID = strongSelf.engine.currentStateID;
             switch (currentID)
             {
                 case RRStateUnReachable:
                 {
                     asyncHandler(RealStatusNotReachable);
                     break;
                 }
                 case RRStateWIFI:
                 {
                     asyncHandler(RealStatusViaWiFi);
                     break;
                 }
                 case RRStateWWAN:
                 {
                     asyncHandler(RealStatusViaWWAN);
                     break;
                 }
                     
                 default:
                 {
                     NSLog(@"warning! reachState uncertain! state unmatched, treat as unreachable temporary");
                     asyncHandler(RealStatusNotReachable);
                     break;
                 }
             }
         }
     }];
}

- (ReachabilityStatus)currentReachabilityStatus
{
    RRStateID currentID = self.engine.currentStateID;
    
    switch (currentID)
    {
        case RRStateUnReachable:
        {
            return RealStatusNotReachable;
        }
        case RRStateWIFI:
        {
            return RealStatusViaWiFi;
        }
        case RRStateWWAN:
        {
            return RealStatusViaWWAN;
        }
        case RRStateLoading:
        {
            // status on loading, return local status temporary.
            return (ReachabilityStatus)(GLocalConnection.currentLocalConnectionStatus);
        }
            
        default:
        {
            NSLog(@"No normal status matched, return unreachable temporary");
            return RealStatusNotReachable;
        }
    }
}

- (void)setHostForPing:(NSString *)hostForPing
{
    _hostForPing = nil;
    _hostForPing = [hostForPing copy];
    
    GPingHelper.host = _hostForPing;
}

- (WWANAccessType)currentWWANtype
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
    {
        CTTelephonyNetworkInfo *teleInfo= [[CTTelephonyNetworkInfo alloc] init];
        NSString *accessString = teleInfo.currentRadioAccessTechnology;
        if ([accessString length] > 0)
        {
            return [self accessTypeForString:accessString];
        }
        else
        {
            return WWANTypeUnknown;
        }
    }
    else
    {
        return WWANTypeUnknown;
    }
}

#pragma mark - inner methods
- (NSString *)paramValueFromStatus:(LocalConnectionStatus)status
{
    switch (status)
    {
        case LC_UnReachable:
        {
            return kParamValueUnReachable;
        }
        case LC_WiFi:
        {
          return kParamValueWIFI;
        }
        case LC_WWAN:
        {
            return kParamValueWWAN;
        }
           
        default:
        {
            NSLog(@"RealReachability error! paramValueFromStatus not matched!");
            return @"";
        }
    }
}

// auto checking after every autoCheckInterval minutes
- (void)autoCheckReachability
{
    if (!self.isNotifying)
    {
        return;
    }
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, self.autoCheckInterval*60*NSEC_PER_SEC);
    __weak __typeof(self)weakSelf = self;
    dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf reachabilityWithBlock:nil];
        [strongSelf autoCheckReachability];
    });
}

- (WWANAccessType)accessTypeForString:(NSString *)accessString
{
    if ([self.typeStrings4G containsObject:accessString])
    {
        return WWANType4G;
    }
    else if ([self.typeStrings3G containsObject:accessString])
    {
        return WWANType3G;
    }
    else if ([self.typeStrings2G containsObject:accessString])
    {
        return WWANType2G;
    }
    else
    {
        return WWANTypeUnknown;
    }
}

#pragma mark - Notification observer
- (void)localConnectionChanged:(NSNotification *)notification
{
    LocalConnection *lc = (LocalConnection *)notification.object;
    LocalConnectionStatus lcStatus = [lc currentLocalConnectionStatus];
    NSLog(@"currentLocalConnectionStatus:%@",@(lcStatus));
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLocalConnectionCallback), kEventKeyParam:[self paramValueFromStatus:lcStatus]};
    NSInteger rtn = [self.engine receiveInput:inputDic];
    
    if (rtn == 0) // state changed & state available, post notification.
    {
        if ([self.engine isCurrentStateAvailable])
        {
            // already in main thread.
            [[NSNotificationCenter defaultCenter] postNotificationName:kRealReachabilityChangedNotification
                                                                object:self];
            // To make sure your reachability is "Real".
            [self reachabilityWithBlock:nil];
        }
    }
}

@end

