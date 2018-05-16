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

#define kDefaultHost @"www.apple.com"
#define kDefaultCheckInterval 2.0f
#define kDefaultPingTimeout 2.0f

#define kMinAutoCheckInterval 0.3f
#define kMaxAutoCheckInterval 60.0f

NSString *const kRealReachabilityChangedNotification = @"kRealReachabilityChangedNotification";

@interface RealReachability()
@property (nonatomic, strong) FSMEngine *engine;
@property (nonatomic, assign) BOOL isNotifying;

@property (nonatomic,strong) NSArray *typeStrings4G;
@property (nonatomic,strong) NSArray *typeStrings3G;
@property (nonatomic,strong) NSArray *typeStrings2G;

@property (nonatomic, assign) ReachabilityStatus previousStatus;

/// main helper
@property (nonatomic, strong) PingHelper *pingHelper;

/// for double check
@property (nonatomic, strong) PingHelper *pingChecker;
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
        _hostForCheck = kDefaultHost;
        _autoCheckInterval = kDefaultCheckInterval;
        _pingTimeout = kDefaultPingTimeout;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appBecomeActive)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        _pingHelper = [[PingHelper alloc] init];
        _pingChecker = [[PingHelper alloc] init];
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
    self.previousStatus = RealStatusUnknown;
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLoad)};
    [self.engine receiveInput:inputDic];
    
    [GLocalConnection startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localConnectionHandler:)
                                                 name:kLocalConnectionChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localConnectionHandler:)
                                                 name:kLocalConnectionInitializedNotification
                                               object:nil];
    
    self.pingHelper.host = _hostForPing;
    self.pingHelper.timeout = self.pingTimeout;
    
    self.pingChecker.host = _hostForCheck;
    self.pingChecker.timeout = self.pingTimeout;
    
    [self autoCheckReachability];
}

- (void)stopNotifier
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLocalConnectionChangedNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLocalConnectionInitializedNotification
                                                  object:nil];
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventUnLoad)};
    [self.engine receiveInput:inputDic];
    
    [GLocalConnection stopNotifier];
    
    self.isNotifying = NO;
}

#pragma mark - outside invoke

- (void)reachabilityWithBlock:(void (^)(ReachabilityStatus status))asyncHandler
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
    [self.pingHelper pingWithBlock:^(BOOL isSuccess)
     {
         __strong __typeof(weakSelf)strongSelf = weakSelf;
         if (isSuccess)
         {
             ReachabilityStatus status = [self currentReachabilityStatus];
             if (status != RealStatusNotReachable && status != RealStatusUnknown) //state available & ping success
             {
                 NSDictionary *inputDic = @{kEventKeyID:@(RREventPingCallback), kEventKeyParam:@(YES)};
                 NSInteger rtn = [strongSelf.engine receiveInput:inputDic];
                 if (rtn == 0 && [strongSelf.engine isCurrentStateAvailable]) //state changed & state available, post notification.
                 {
                     strongSelf.previousStatus = status;
                 }
                 // no need to post the notification because the status is not changing.
                 if (asyncHandler != nil)
                 {
                     ReachabilityStatus currentStatus = [strongSelf currentReachabilityStatus];
                     asyncHandler(currentStatus);
                 }
             }else //state not available & ping success
             {
                 // delay 1 seconds, then make a double check is really success.
                 dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1*NSEC_PER_SEC));
                 __weak __typeof(self)weakSelf = self;
                 dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     __strong __typeof(weakSelf)self = weakSelf;
                     [self makeDoublePingConnectCheck:true handler:asyncHandler];
                 });
             }
         }
         else
         {
             // delay 1 seconds, then make a double check.
             dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1*NSEC_PER_SEC));
             __weak __typeof(self)weakSelf = self;
             dispatch_after(time, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 __strong __typeof(weakSelf)self = weakSelf;
                 [self makeDoublePingConnectCheck:false handler:asyncHandler];
             });
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

- (ReachabilityStatus)previousReachabilityStatus
{
    return self.previousStatus;
}

- (void)setHostForPing:(NSString *)hostForPing
{
    _hostForPing = nil;
    _hostForPing = [hostForPing copy];
    
    self.pingHelper.host = _hostForPing;
}

- (void)setHostForCheck:(NSString *)hostForCheck
{
    _hostForCheck = nil;
    _hostForCheck = [hostForCheck copy];
    
    self.pingChecker.host = _hostForCheck;
}

- (void)setPingTimeout:(NSTimeInterval)pingTimeout
{
    _pingTimeout = pingTimeout;
    self.pingHelper.timeout = pingTimeout;
    self.pingChecker.timeout = pingTimeout;
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
- (void)makeDoublePingConnectCheck:(Boolean)connect handler:(void (^)(ReachabilityStatus status))asyncHandler
{
    __weak __typeof(self)weakSelf = self;
    [self.pingChecker pingWithBlock:^(BOOL isSuccess) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (isSuccess == connect) //double check pass
        {
            ReachabilityStatus status = [strongSelf currentReachabilityStatus];
            NSDictionary *inputDic = @{kEventKeyID:@(RREventPingCallback), kEventKeyParam:@(isSuccess)};
            NSInteger rtn = [strongSelf.engine receiveInput:inputDic];
            if (rtn == 0 && [strongSelf.engine isCurrentStateAvailable]) // state changed & state available, post notification.
            {
                strongSelf.previousStatus = status;
                //make change post notification.
                __weak __typeof(strongSelf)deepWeakSelf = strongSelf;
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof(deepWeakSelf)deepStrongSelf = deepWeakSelf;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kRealReachabilityChangedNotification
                                                                        object:deepStrongSelf];
                });
            }
        }
        
        if (asyncHandler != nil)
        {
            ReachabilityStatus currentStatus = [strongSelf currentReachabilityStatus];
            asyncHandler(currentStatus);
        }
    }];
}

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
    
    if (self.autoCheckInterval < kMinAutoCheckInterval)
    {
        self.autoCheckInterval = kMinAutoCheckInterval;
    }
    
    if (self.autoCheckInterval > kMaxAutoCheckInterval)
    {
        self.autoCheckInterval = kMaxAutoCheckInterval;
    }
    
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.autoCheckInterval*60*NSEC_PER_SEC));
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
- (void)localConnectionHandler:(NSNotification *)notification
{
    LocalConnection *lc = (LocalConnection *)notification.object;
    LocalConnectionStatus lcStatus = [lc currentLocalConnectionStatus];
    //NSLog(@"currentLocalConnectionStatus:%@, receive notification:%@",@(lcStatus), notification.name);
    ReachabilityStatus status = [self currentReachabilityStatus];
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLocalConnectionCallback), kEventKeyParam:[self paramValueFromStatus:lcStatus]};
    NSInteger rtn = [self.engine receiveInput:inputDic];
    
    if (rtn == 0) // state changed & state available, post notification.
    {
        if ([self.engine isCurrentStateAvailable])
        {
            self.previousStatus = status;
            
            // already in main thread.
            if ([notification.name isEqualToString:kLocalConnectionChangedNotification])
            {
                [[NSNotificationCenter defaultCenter] postNotificationName:kRealReachabilityChangedNotification
                                                                    object:self];
            }
    
            if (lcStatus != LC_UnReachable)
            {
                // To make sure your reachability is "Real".
                [self reachabilityWithBlock:nil];
            }
        }
    }
}

@end

