//
//  RRStateUtil.h
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RRDefines.h"

@interface RRStateUtil : NSObject

+ (RRStateID)RRStateFromValue:(NSString *)LCEventValue;

+ (RRStateID)RRStateFromPingFlag:(BOOL)isSuccess;

@end
