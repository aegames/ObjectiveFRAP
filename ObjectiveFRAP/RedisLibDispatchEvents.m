//
//  RedisLibDispatchEvents.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 4/22/14.
//  Copyright (c) 2014 Alleged Entertainment. All rights reserved.
//

#import "RedisLibDispatchEvents.h"
#import "hiredis-libdispatch.h"

@interface RedisLibDispatchEvents ()
-(int)setupContext;
@end


@implementation RedisLibDispatchEvents
@synthesize context, reading, writing, rev, wev, queue;

-(id)init {
    self.reading = 0;
    self.writing = 0;
    
    return self;
}

-(id)initWithContext:(redisAsyncContext *)c queue:(dispatch_queue_t)q {
    self.queue = q;
    self.context = c;
    return [self init];
}

-(void)setContext:(redisAsyncContext *)theContext {
    context = theContext;
    int err = [self setupContext];
    if (err != REDIS_OK) {
        self.context = nil;
        NSLog(@"Error %d initializing Redis context", err);
    }
}

-(int)setupContext {
    redisAsyncContext *ac = self.context;
    redisContext *c = &(ac->c);
    
    // Nothing should be attached when something is already attached
    if (ac->ev.data != NULL)
        return REDIS_ERR;
    
    // Initialize and install read/write events
    self.rev = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                                   c->fd, 0, self.queue);
    if (rev == NULL)
        return REDIS_ERR_IO;
    dispatch_source_set_event_handler(rev, ^{
        redisAsyncHandleRead(ac);
    });
    
    self.wev = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE,
                                                   c->fd, 0, self.queue);
    if (wev == NULL)
        return REDIS_ERR_IO;
    dispatch_source_set_event_handler(wev, ^{
        redisAsyncHandleWrite(ac);
    });
    
    // Register functions to start/stop listening for events
    ac->ev.addRead = redisLibdispatchAddRead;
    ac->ev.delRead = redisLibdispatchDelRead;
    ac->ev.addWrite = redisLibdispatchAddWrite;
    ac->ev.delWrite = redisLibdispatchDelWrite;
    ac->ev.cleanup = redisLibdispatchCleanup;
    ac->ev.data = (__bridge void *)(self);
    
    return REDIS_OK;
}

@end
