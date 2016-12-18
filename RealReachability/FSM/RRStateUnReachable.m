//
//  RRStateUnReachable.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import "RRStateUnReachable.h"

@implementation RRStateUnReachable

- (RRStateID)onEvent:(NSDictionary *)event withError:(NSError **)error
{
    RRStateID resStateID = RRStateIDUnreachable;
    
    NSNumber *eventID = event[kEventKeyID];
    
    switch ([eventID intValue])
    {
        case RREventUnLoad:
        {
            resStateID = RRStateIDUnloaded;
            break;
        }
        case RREventPingCallback:
        {
            NSNumber *eventParam = event[kEventKeyParam];
            resStateID = [RRStateUtil RRStateFromPingFlag:[eventParam boolValue]];
            break;
        }
        case RREventLocalConnectionCallback:
        {
            resStateID = [RRStateUtil RRStateFromValue:event[kEventKeyParam]];
            break;
        }
        default:
        {
            if (error != NULL)
            {
                *error = [NSError errorWithDomain:@"FSM" code:kFSMErrorNotAccept userInfo:nil];
            }
            break;
        }
    }
    return resStateID;
}

@end
