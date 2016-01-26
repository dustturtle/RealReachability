//
//  FSMDefines.h
//  RealReachability
//  Defines of FSM (finite state machine)
//
//  Created by Dustturtle on 16/1/19.
//  Copyright © 2016 Dustturtle. All rights reserved.
//

#ifndef FSMDefine_h
#define FSMDefine_h

#define kEventKeyID         @"event_id"
#define kEventKeyParam      @"event_param"

#define kParamValueUnReachable @"ParamValueUnReachable"
#define kParamValueWWAN        @"ParamValueWWAN"
#define kParamValueWIFI        @"ParamValueWIFI"

typedef enum
{
    RRStateInvalid = -1,
    RRStateUnloaded = 0,
    RRStateLoading,
    RRStateUnReachable,
    RRStateWIFI,
    RRStateWWAN
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

#endif /* FSMDefine_h */
