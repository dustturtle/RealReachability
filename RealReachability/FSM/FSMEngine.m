//
//  FSMEngine.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "FSMEngine.h"
#import "ReachState.h"
#import "ReachStateWIFI.h"
#import "ReachStateUnloaded.h"
#import "ReachStateWWAN.h"
#import "ReachStateUnReachable.h"
#import "ReachStateLoading.h"

#if (!defined(DEBUG))
#define NSLog(...)
#endif

@interface FSMEngine()

@property (nonatomic, assign) RRStateID currentStateID;
@property (nonatomic, strong) NSArray *allStates;

@end

@implementation FSMEngine

- (id)init
{
    if (self = [super init])
    {
        // created only once
        _allStates = @[[ReachStateUnloaded state], [ReachStateLoading state], [ReachStateUnReachable state], [ReachStateWIFI state], [ReachStateWWAN state]];
    }
    return self;
}

- (void)dealloc
{
    self.allStates = nil;
}

- (void)start
{
    self.currentStateID = RRStateUnloaded;
}

- (NSInteger)receiveInput:(NSDictionary *)dic
{
    NSError *error = nil;
    ReachState *currentState = self.allStates[self.currentStateID];
    RRStateID newStateID = [currentState onEvent:dic withError:&error];
    if (error)
    {
        NSLog(@"onEvent error:%@", error);
    }
  
    RRStateID previousStateID = self.currentStateID;
    self.currentStateID = newStateID;
    //NSLog(@"curStateID is %@", @(self.currentStateID));
    
    return (previousStateID == self.currentStateID) ? -1 : 0;
}

- (BOOL)isCurrentStateAvailable
{
    if (self.currentStateID == RRStateUnReachable || self.currentStateID == RRStateWWAN
        || self.currentStateID == RRStateWIFI)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end

