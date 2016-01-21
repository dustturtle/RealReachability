//
//  FSMStateUtil.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//

#import "FSMStateUtil.h"

@implementation FSMStateUtil

+ (RRStateID)RRStateFromValue:(NSString *)LCEventValue
{
    if ([LCEventValue isEqualToString:kParamValueUnReachable])
    {
        return RRStateUnReachable;
    }
    else if ([LCEventValue isEqualToString:kParamValueWWAN])
    {
        return RRStateWWAN;
    }
    else if ([LCEventValue isEqualToString:kParamValueWIFI])
    {
        return RRStateWIFI;
    }
    else
    {
        return RRStateInvalid;
    }
}

@end
