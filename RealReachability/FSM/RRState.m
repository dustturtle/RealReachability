//
//  RRState.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "RRState.h"

@implementation RRState

+ (id)state
{
    return [[self alloc] init];
}

- (RRStateID)onEvent:(NSDictionary *)event withError:(NSError **)error
{
    return RRStateIDInvalid;
}

@end
