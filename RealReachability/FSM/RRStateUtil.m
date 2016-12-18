//
//  RRStateUtil.m
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//

#import "RRStateUtil.h"
#import "RRLocalConnection.h"
#import "RealReachability.h"

@implementation RRStateUtil

+ (RRStateID)RRStateFromValue:(NSString *)LCEventValue {
    if ([LCEventValue isEqualToString:kParamValueUnReachable]) {
        return RRStateIDUnreachable;
    }
    else if ([LCEventValue isEqualToString:kParamValueWWAN]) {
        return RRStateIDWWAN;
    }
    else if ([LCEventValue isEqualToString:kParamValueWIFI]) {
        return RRStateIDWIFI;
    }
    else {
		if ([RealReachability loggingEnabled]) {
			NSLog(@"Error! no matching LCEventValue!");
		}
        return RRStateIDInvalid;
    }
}

+ (RRStateID)RRStateFromPingFlag:(BOOL)isSuccess {
    LocalConnectionStatus status = [RRLocalConnection sharedInstance].currentLocalConnectionStatus;
    
    if (!isSuccess) {
        return RRStateIDUnreachable;
    }
    else {
        switch (status) {
            case LC_Unreachable: {
				if ([RealReachability loggingEnabled]) {
					NSLog(@"MisMatch! RRStateFromPingFlag success, but LC_Unreachable!");
				}
                return RRStateIDUnreachable;
            }
            case LC_WiFi: {
                return RRStateIDWIFI;
            }
            case LC_WWAN: {
                return RRStateIDWWAN;
            }
            default: {
				if ([RealReachability loggingEnabled]) {
					NSLog(@"RealReachability error! RRStateFromPingFlag not matched!");
				}
                return RRStateIDWIFI;
            }
        }
    }
}

@end
