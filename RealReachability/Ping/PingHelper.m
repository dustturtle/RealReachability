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
    
    [self clearPingFoundation];
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
    NSLog(@"pingWithBlock");
    if (completion)
    {
        // copy the block, then added to the blocks array.
        @synchronized(self)
        {
            [self.completionBlocks addObject:[completion copy]];
        }
    }
    
    if (!self.isPinging)
    {
        // MUST make sure pingFoundation in mainThread
        __weak __typeof(self)weakSelf = self;
        if (![[NSThread currentThread] isMainThread]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf startPing];
            });
        }
        else
        {
            [self startPing];
        }
    }
}

- (void)clearPingFoundation
{
    //NSLog(@"clearPingFoundation");
    
    if (self.pingFoundation)
    {
        [self.pingFoundation stop];
        self.pingFoundation.delegate = nil;
        self.pingFoundation = nil;
    }
}

- (void)startPing
{
    NSLog(@"startPing");
    [self clearPingFoundation];
    
    self.isPinging = YES;
    
    self.pingFoundation = [[PingFoundation alloc] initWithHostName:self.host];
    self.pingFoundation.delegate = self;
    [self.pingFoundation start];
    
    [self performSelector:@selector(pingTimeOut) withObject:nil afterDelay:2.0f];
}

- (void)setHost:(NSString *)host
{
    _host = nil;
    _host = [host copy];
    
    self.pingFoundation.delegate = nil;
    self.pingFoundation = nil;
    
    self.pingFoundation = [[PingFoundation alloc] initWithHostName:_host];
    
    self.pingFoundation.delegate = self;
}

#pragma mark - inner methods

- (void)endWithFlag:(BOOL)isSuccess
{
    // TODO(optimization):
    //somewhere around here we should introduce a double check after 3 seconds on another host,
    // if maybe not truely failed.
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pingTimeOut) object:nil];
    
    if (!self.isPinging)
    {
        return;
    }
    
    self.isPinging = NO;
    [self clearPingFoundation];
    
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
    //NSLog(@"didStartWithAddress");
    [self.pingFoundation sendPingWithData:nil];
}

- (void)pingFoundation:(PingFoundation *)pinger didFailWithError:(NSError *)error
{
    //NSLog(@"didFailWithError, error=%@", error);
    [self endWithFlag:NO];
}

- (void)pingFoundation:(PingFoundation *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error
{
    //NSLog(@"didFailToSendPacket, sequenceNumber = %@, error=%@", @(sequenceNumber), error);
    [self endWithFlag:NO];
}

- (void)pingFoundation:(PingFoundation *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    //NSLog(@"didReceivePingResponsePacket, sequenceNumber = %@", @(sequenceNumber));
    [self endWithFlag:YES];
}

- (void)pingFoundation:(PingFoundation *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    //NSLog(@"didSendPacket, sequenceNumber = %@", @(sequenceNumber));
}

- (void)pingFoundation:(PingFoundation *)pinger didReceiveUnexpectedPacket:(NSData *)packet
{
    //NSLog(@"didReceiveUnexpectedPacket");
}

#pragma mark - TimeOut handler

- (void)pingTimeOut
{
    //NSLog(@"pingTimeOut");
    
    if (!self.isPinging)
    {
        return;
    }
    
    self.isPinging = NO;
    [self clearPingFoundation];
    
    @synchronized(self)
    {
        for (void (^completion)(BOOL) in self.completionBlocks)
        {
            completion(NO);
        }
        [self.completionBlocks removeAllObjects];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPingResultNotification
                                                            object:[NSNumber numberWithBool:NO]];
    });
}

@end
