//
//  PingHelper.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "PingHelper.h"
#import "PingFoundation.h"

#if (!defined(DEBUG))
#define NSLog(...)
#endif

// We post the ping result to this notification,
// which is a NSNumber from BOOL; YES -> success , NO -> failure.
NSString *const kPingResultNotification = @"kPingResultNotification";

@interface PingHelper() <PingFoundationDelegate>

@property (nonatomic, strong) NSMutableArray *completionBlocks;
@property(nonatomic, strong) PingFoundation *pingFoundation;
@property (nonatomic, assign) BOOL isPinging;

@end

@implementation PingHelper

#pragma mark - Life Circle

- (id)init
{
    if ((self = [super init]))
    {
        _isPinging = NO;
        
        _completionBlocks = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [self.completionBlocks removeAllObjects];
    self.completionBlocks = nil;
}

#pragma mark - Singlton Method

+ (instancetype)sharedInstance
{
    static id pingHelper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pingHelper = [[self alloc] init];
    });
    
    return pingHelper;
}

#pragma mark - actions

- (void)pingWithBlock:(void (^)(BOOL isSuccess))completion
{
    //NSLog(@"pingWithBlock");
    if (completion)
    {
        // Temp: need to copy the block?
        @synchronized(self)
        {
            [self.completionBlocks addObject:completion];
        }
    }
    
    if (!self.isPinging)
    {
        // safe protection for exceptional situation, background app or multi-thread, eg.
        [self.pingFoundation stop];
        
        // MUST make sure pingFoundation in mainThread
        __weak __typeof(self)weakSelf = self;
        if (![[NSThread currentThread] isMainThread]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                strongSelf.isPinging = YES;
                [strongSelf.pingFoundation start];
                
                [strongSelf performSelector:@selector(pingTimeOut) withObject:nil afterDelay:2.0f];
            });
        }
        else
        {
            self.isPinging = YES;
            [self.pingFoundation start];
            
            [self performSelector:@selector(pingTimeOut) withObject:nil afterDelay:2.0f];
        }
    }
}

- (void)setHost:(NSString *)host
{
    _host = nil;
    _host = [host copy];
    
    self.pingFoundation.delegate = nil;
    self.pingFoundation = nil;
    
    self.pingFoundation = [PingFoundation pingFoundationWithHostName:_host];
    self.pingFoundation.delegate = self;
}

#pragma mark - inner methods

- (void)endWithFlag:(BOOL)isSuccess
{
    if (!self.isPinging)
    {
        return;
    }
    
    self.isPinging = NO;
    [self.pingFoundation stop];
    
    @synchronized(self)
    {
        for (void (^completion)(BOOL) in self.completionBlocks)
        {
            completion(isSuccess);
        }
        [self.completionBlocks removeAllObjects];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPingResultNotification
                                                            object:[NSNumber numberWithBool:isSuccess]];
        });
}

#pragma mark - PingFoundation delegate

// When the pinger starts, send the ping immediately
- (void)pingFoundation:(PingFoundation *)pinger didStartWithAddress:(NSData *)address
{
    [self.pingFoundation sendPingWithData:nil];
}

- (void)pingFoundation:(PingFoundation *)pinger didFailWithError:(NSError *)error
{
    [self endWithFlag:NO];
}

- (void)PingFoundation:(PingFoundation *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error
{
    [self endWithFlag:NO];
}

- (void)pingFoundation:(PingFoundation *)pinger didReceivePingResponsePacket:(NSData *)packet
{
    [self endWithFlag:YES];
}

- (void)pingFoundation:(PingFoundation *)pinger didSendPacket:(NSData *)packet
{
    
}

#pragma mark - TimeOut handler

- (void)pingTimeOut
{
    [self endWithFlag:NO];
}

@end
