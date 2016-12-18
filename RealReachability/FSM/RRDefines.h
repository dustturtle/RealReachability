//
//  RRDefines.h
//  RealReachability
//  Defines of FSM (finite state machine)
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#ifndef RRDefine_h
#define RRDefine_h

#define kEventKeyID         @"event_id"
#define kEventKeyParam      @"event_param"

#define kParamValueUnReachable @"ParamValueUnReachable"
#define kParamValueWWAN        @"ParamValueWWAN"
#define kParamValueWIFI        @"ParamValueWIFI"

typedef enum
{
    RRStateIDInvalid = -1,
    RRStateIDUnloaded = 0,
    RRStateIDLoading,
    RRStateIDUnreachable,
    RRStateIDWIFI,
    RRStateIDWWAN
}RRStateID;

typedef enum
{
    RREventLoad = 0,
    RREventUnLoad,
    RREventLocalConnectionCallback,
    RREventPingCallback
}RREventID;

/// FSM error codes below
#define kFSMErrorNotAccept 13

#endif /* RRDefine_h */
