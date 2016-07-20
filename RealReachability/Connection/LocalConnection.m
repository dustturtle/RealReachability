//
//  LocalConnection.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//

#import "LocalConnection.h"
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

#if (!defined(DEBUG))
#define NSLog(...)
#endif

NSString *const kLocalConnectionInitializedNotification = @"kLocalConnectionInitializedNotification";
NSString *const kLocalConnectionChangedNotification = @"kLocalConnectionChangedNotification";

@interface LocalConnection ()
@property (assign, nonatomic) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, strong) dispatch_queue_t         reachabilitySerialQueue;

-(void)localConnectionChanged;
@end

// Start listening for reachability notifications on the current run loop
static void LocalConnectionCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target)
    LocalConnection *connection = ((__bridge LocalConnection*)info);
    
    @autoreleasepool
    {
        [connection localConnectionChanged];
    }
}

static NSString *connectionFlags(SCNetworkReachabilityFlags flags)
{
    return [NSString stringWithFormat:@"%c%c %c%c%c%c%c%c%c",
            (flags & kSCNetworkReachabilityFlagsIsWWAN)               ? 'W' : '-',
            (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
            (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
            (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
            (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
            (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'];
}

@implementation LocalConnection

#pragma mark - Life Circle

- (id)init
{
    if ((self = [super init]))
    {
        struct sockaddr_in address;
        bzero(&address, sizeof(address));
        address.sin_len = sizeof(address);
        address.sin_family = AF_INET;
        _reachabilityRef = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *) &address);
        
        _reachabilitySerialQueue = dispatch_queue_create("com.dustturtle.realreachability", NULL);
    }
    return self;
}

- (void)dealloc
{
    [self stopNotifier];
    
    if(_reachabilityRef != NULL)
    {
        CFRelease(_reachabilityRef);
        _reachabilityRef = NULL;
    }
    
    self.reachabilitySerialQueue = nil;
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
    SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
    context.info = (__bridge void *)self;
    
    if(SCNetworkReachabilitySetCallback(self.reachabilityRef, LocalConnectionCallback, &context))
    {
        // Set it as our reachability queue, which will retain the queue
        if(!SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.reachabilitySerialQueue))
        {
            SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
            NSLog(@"SCNetworkReachabilitySetDispatchQueue() failed: %s", SCErrorString(SCError()));
        }
    }
    else
    {
        NSLog(@"SCNetworkReachabilitySetCallback() failed: %s", SCErrorString(SCError()));
    }

    // First time we come in, notify the initialization of local connection.
    
    self.isReachable = [self _isReachable];
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLocalConnectionInitializedNotification
                                                            object:strongSelf];
    });
}

-(void)stopNotifier
{
    // First: stop any callbacks.
    SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
    
    // Second: unregister target from the GCD serial dispatch queue.
    SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, NULL);
}

#pragma mark - outside invoke
- (LocalConnectionStatus)currentLocalConnectionStatus
{
    if ([self _isReachable])
    {
        if ([self isReachableViaWiFi])
        {
            return LC_WiFi;
        }
        else
        {
            return LC_WWAN;
        }
    }
    else
    {
        return LC_UnReachable;
    }
}

#pragma mark - inner methods

- (void)localConnectionChanged
{
    self.isReachable = [self _isReachable];
    
    // this makes sure the change notification happens on the MAIN THREAD
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [[NSNotificationCenter defaultCenter] postNotificationName:kLocalConnectionChangedNotification
                                                            object:strongSelf];
    });
}

// for inner testing & debugging
- (NSString *)currentConnectionFlags
{
    return connectionFlags([self reachabilityFlags]);
}

-(SCNetworkReachabilityFlags)reachabilityFlags
{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        return flags;
    }
    
    return 0;
}

#pragma mark - LocalReachability

/// added underline prefix to distinguish the method from the property "isReachable"
- (BOOL)_isReachable
{
    SCNetworkReachabilityFlags flags;
    
    if(!SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        return NO;
    }
    else
    {
        return [self isReachableWithFlags:flags];
    }
}

- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags
{
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // if target host is not reachable
        return NO;
    }
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        // if target host is reachable and no connection is required
        //  then we'll assume (for now) that you're on Wi-Fi
        return YES;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        // ... and the connection is on-demand (or on-traffic) if the
        //     calling application is using the CFSocketStream or higher APIs
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            // ... and no [user] intervention is needed
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isReachableViaWWAN
{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        if(flags & kSCNetworkReachabilityFlagsReachable)
        {
            if(flags & kSCNetworkReachabilityFlagsIsWWAN)
            {
                return YES;
            }
        }
    }
    
    return NO;
}

-(BOOL)isReachableViaWiFi
{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        if((flags & kSCNetworkReachabilityFlagsReachable))
        {
            if((flags & kSCNetworkReachabilityFlagsIsWWAN))
            {
                return NO;
            }
            
            return YES;
        }
    }
    
    return NO;
}

@end
