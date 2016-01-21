//
//  RealReachability.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright © 2016 QCStudio. All rights reserved.
//

#import "RealReachability.h"
#import "FSM/FSMEngine.h"
#import "Connection/LocalConnection.h"
#import "Ping/PingHelper.h"

#if (!defined(DEBUG))
#define NSLog(...)
#endif

#define kDefaultHost @"www.baidu.com"

NSString *const kRealReachabilityChangedNotification = @"kRealReachabilityChangedNotification";

@interface RealReachability()

@property (nonatomic, strong) FSMEngine *engine;

@end

@implementation RealReachability

#pragma mark - Life Circle

- (id)init
{
    if ((self = [super init]))
    {
        _engine = [[FSMEngine alloc] init];
        [_engine start];
    }
    return self;
}

- (void)dealloc
{
    self.engine = nil;
    
    [GLocalConnection stopNotifier];
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
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLoad)};
    [self.engine reciveInput:inputDic];
    
    [GLocalConnection startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localConnectionChanged:)
                                                 name:kLocalConnectionChangedNotification
                                               object:nil];
    
    GPingHelper.host = kDefaultHost;
}

- (void)stopNotifier
{
    NSDictionary *inputDic = @{kEventKeyID:@(RREventUnLoad)};
    [self.engine reciveInput:inputDic];
    
    [GLocalConnection stopNotifier];
}

#pragma mark - outside invoke

- (void)reachabilityWithBlock:(void (^)(ReachabilityStatus))asyncHandler
{
    __weak __typeof(self)weakSelf = self;
    [GPingHelper pingWithBlock:^(BOOL isSuccess)
     {
         __strong __typeof(weakSelf)strongSelf = weakSelf;
         NSDictionary *inputDic = @{kEventKeyID:@(RREventPingCallback), kEventKeyParam:@(isSuccess)};
         NSInteger rtn = [strongSelf.engine reciveInput:inputDic];
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
                     asyncHandler(NotReachable);
                 }
                 case RRStateWIFI:
                 {
                     asyncHandler(ReachableViaWiFi);
                 }
                 case RRStateWWAN:
                 {
                     asyncHandler(ReachableViaWWAN);
                 }
                     
                 default:
                 {
                     NSLog(@"warning! reachState uncertain! state unmatched, treat as unreachable temporary");
                     asyncHandler(NotReachable);
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
            return NotReachable;
        }
        case RRStateWIFI:
        {
            return ReachableViaWiFi;
        }
        case RRStateWWAN:
        {
            return ReachableViaWWAN;
        }
            
        default:
        {
            NSLog(@"No normal status matched, return unreachable temporary");
            return NotReachable;
        }
    }
}

- (void)setHostForPing:(NSString *)hostForPing
{
    _hostForPing = nil;
    _hostForPing = [hostForPing copy];
    
    GPingHelper.host = _hostForPing;
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

#pragma mark - Notification observer
- (void)localConnectionChanged:(NSNotification *)notification
{
    LocalConnection *lc = (LocalConnection *)notification.object;
    LocalConnectionStatus lcStatus = [lc currentLocalConnectionStatus];
    NSLog(@"currentLocalConnectionStatus:%@",@(lcStatus));
    
    NSDictionary *inputDic = @{kEventKeyID:@(RREventLocalConnectionCallback), kEventKeyParam:[self paramValueFromStatus:lcStatus]};
    NSInteger rtn = [self.engine reciveInput:inputDic];
    
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

