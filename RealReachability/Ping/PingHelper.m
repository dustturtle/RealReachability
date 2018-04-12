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
        _timeout = 2.0f;
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

#pragma mark - actions

- (void)pingWithBlock:(void (^)(BOOL isSuccess))completion
{
    //NSLog(@"pingWithBlock");
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
    //NSLog(@"startPing");
    [self clearPingFoundation];
    
    self.isPinging = YES;
    
    self.pingFoundation = [[PingFoundation alloc] initWithHostName:self.host];
    self.pingFoundation.delegate = self;
    [self.pingFoundation start];
    
    [self performSelector:@selector(pingTimeOut) withObject:nil afterDelay:self.timeout];
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

- (void)doubleCheck
{
    [self clearPingFoundation];
    
    self.isPinging = YES;
    
    self.pingFoundation = [[PingFoundation alloc] initWithHostName:self.hostForCheck];
    self.pingFoundation.delegate = self;
    [self.pingFoundation start];
    
}

- (void)endWithFlag:(BOOL)isSuccess
{
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

#pragma mark - TimeOut handler

- (void)pingTimeOut
{
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
}

@end
