//
//  ReachState.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 QCStudio. All rights reserved.
//

#import "ReachState.h"

@implementation ReachState

+ (id)state
{
    return [[self alloc] init];
}

- (RRStateID)onEvent:(NSDictionary *)event withError:(NSError **)error
{
    return RRStateInvalid;
}

@end
