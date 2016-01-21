//
//  ReachStateUnReachable.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 QCStudio. All rights reserved.
//

#import "ReachStateUnReachable.h"

@implementation ReachStateUnReachable

- (RRStateID)onEvent:(NSDictionary *)event withError:(NSError **)error
{
    RRStateID resStateID = RRStateUnReachable;
    
    NSNumber *eventID = event[kEventKeyID];
    
    switch ([eventID intValue])
    {
        case RREventUnLoad:
        {
            resStateID = RRStateUnloaded;
            break;
        }
        case RREventPingCallback:
        {
            NSNumber *eventParam = event[kEventKeyParam];
            if ([eventParam boolValue])
            {
                resStateID = RRStateUnReachable;
                NSLog(@"warning! reachState uncertain! receive ping callback when unreachable!");
            }
            else
            {
                resStateID = RRStateUnReachable;
            }
            break;
        }
        case RREventLocalConnectionCallback:
        {
            resStateID = [FSMStateUtil RRStateFromValue:event[kEventKeyParam]];
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
