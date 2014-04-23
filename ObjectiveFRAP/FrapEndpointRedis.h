//
//  FrapEndpointRedis.h
//  ObjectiveFRAP
//
//  Created by Nat Budin on 4/22/14.
//  Copyright (c) 2014 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpoint.h"
#import "hiredis/hiredis.h"
#import "hiredis/async.h"
#import "RedisLibDispatchEvents.h"

@interface FrapEndpointRedis : FrapEndpoint {
    redisAsyncContext *commandContext;
    RedisLibDispatchEvents *commandLibDispatchEvents;
    
    redisAsyncContext *pubsubContext;
    RedisLibDispatchEvents *pubsubLibDispatchEvents;
}

@end
