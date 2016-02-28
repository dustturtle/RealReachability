//
//  FSMEngine.h
//  RealReachability
//  Engine of FSM (finite state machine)
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FSMDefines.h"

@interface FSMEngine : NSObject

@property (nonatomic, readonly) RRStateID currentStateID;
@property (nonatomic, readonly) NSArray *allStates;

- (void)start;

/**
 *  trigger event
 *
 *  @param dic inputDic
 *
 *  @return -1 -> no state changed, 0 ->state changed
 */
- (NSInteger)receiveInput:(NSDictionary *)dic;

- (BOOL)isCurrentStateAvailable;
@end

