//
//  RREngine.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "RREngine.h"
#import "RRState.h"
#import "RRStateWIFI.h"
#import "RRStateUnloaded.h"
#import "RRStateWWAN.h"
#import "RRStateUnReachable.h"
#import "RRStateLoading.h"
#import "RealReachability.h"

@interface RREngine()

@property (nonatomic, assign) RRStateID currentStateID;
@property (nonatomic, strong) NSArray *allStates;

@end

@implementation RREngine

- (id)init
{
    if (self = [super init])
    {
        // created only once
        _allStates = @[[RRStateUnloaded state], [RRStateLoading state], [RRStateUnReachable state], [RRStateWIFI state], [RRStateWWAN state]];
    }
    return self;
}

- (void)dealloc
{
    self.allStates = nil;
}

- (void)start
{
    self.currentStateID = RRStateIDUnloaded;
}

- (NSInteger)receiveInput:(NSDictionary *)dic
{
    NSError *error = nil;
    RRState *currentState = self.allStates[self.currentStateID];
    RRStateID newStateID = [currentState onEvent:dic withError:&error];
    if (error) {
		
		if ([RealReachability loggingEnabled]) {
			NSLog(@"onEvent error:%@", error);
		}
    }
  
    RRStateID previousStateID = self.currentStateID;
    self.currentStateID = newStateID;
    
    return (previousStateID == self.currentStateID) ? -1 : 0;
}

- (BOOL)isCurrentStateAvailable
{
    if (self.currentStateID == RRStateIDUnreachable || self.currentStateID == RRStateIDWWAN
        || self.currentStateID == RRStateIDWIFI)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}

@end

