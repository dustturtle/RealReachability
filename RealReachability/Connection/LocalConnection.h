//
//  LocalConnection.h
//  RealReachability
//
//  Created by Dustturtle on 16/1/9.
//  Copyright (c) 2016 Dustturtle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#define GLocalConnection [LocalConnection sharedInstance]

/// We post self to this notification,
/// then you should invoke currentLocalConnectionStatus method to fetch current status.
extern NSString *const kLocalConnectionChangedNotification;

/// After start observering, we post this notification once,
/// you may invoke currentLocalConnectionStatus method to fetch initial status.
extern NSString *const kLocalConnectionInitializedNotification;

typedef NS_ENUM(NSInteger, LocalConnectionStatus)
{
    LC_UnReachable = 0,
    LC_WWAN        = 1,
    LC_WiFi        = 2
};

@interface LocalConnection : NSObject

/// Newly added property for KVO usage:
/// maybe you only want to observe the local network is available or not.
@property (nonatomic, assign) BOOL isReachable;

+ (instancetype)sharedInstance;

/**
 * Start observering local connection status.
 *
 *  @return success or failure. YES->success
 */
- (void)startNotifier;

/**
 *  Stop observering local connection status.
 */
- (void)stopNotifier;

/**
 *  Return current local connection status immediately.
 *
 *  @return see enum LocalConnectionStatus
 */
- (LocalConnectionStatus)currentLocalConnectionStatus;

@end

