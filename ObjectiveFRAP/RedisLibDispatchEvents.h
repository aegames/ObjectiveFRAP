//
//  RedisLibDispatchEvents.h
//  ObjectiveFRAP
//
//  Created by Nat Budin on 4/22/14.
//  Copyright (c) 2014 Alleged Entertainment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "hiredis/hiredis.h"
#import "hiredis/async.h"

@interface RedisLibDispatchEvents : NSObject

@property (nonatomic) redisAsyncContext *context;
@property int reading, writing;
@property dispatch_queue_t queue;
@property dispatch_source_t rev, wev;

-(id)initWithContext:(redisAsyncContext *)c queue:(dispatch_queue_t)q;

@end
