//
//  PingHelper.h
//  RealReachability
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PingHelper : NSObject

/// You MUST have already set the host before your ping action.
/// Think about that: if you never set this, we don't know where to ping.
@property (nonatomic, copy) NSString *host;

/// Used as a backup for double checking.
@property (nonatomic, copy) NSString *hostForCheck;

/// Ping timeout. Default is 2 seconds
@property (nonatomic, assign) NSTimeInterval timeout;

/**
 *  trigger a ping action with a completion block
 *
 *  @param completion : Async completion block
 */
- (void)pingWithBlock:(void (^)(BOOL isSuccess))completion;

@end
