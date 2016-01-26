//
//  ReachState.h
//  RealReachability
//  Only handle events here: receive event in state,then transfer current state.
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FSMStateUtil.h"

@interface ReachState : NSObject

/**
 *  factory method
 *
 *  @return state object
 */
+ (id)state;

/**
 *  vitual method, for subclass override
 *
 *  @param event see FSMDefines.h,dictionary with keys:kEventKeyID,kEventKeyParam
 *  @param error error pointer
 *
 *  @return return value description
 */
- (RRStateID)onEvent:(NSDictionary *)event withError:(NSError **)error;

@end
