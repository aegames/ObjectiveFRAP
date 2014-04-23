#ifndef __HIREDIS_LIBDISPATCH_H__
#define __HIREDIS_LIBDISPATCH_H__

#include <dispatch/dispatch.h>
#import "RedisLibDispatchEvents.h"

static void redisLibdispatchAddRead(void *privdata) {
    RedisLibDispatchEvents *e = (__bridge RedisLibDispatchEvents*)privdata;
    if (!e.reading) {
        e.reading = 1;
        dispatch_resume(e.rev);
    }
}

static void redisLibdispatchDelRead(void *privdata) {
    RedisLibDispatchEvents *e = (__bridge RedisLibDispatchEvents*)privdata;
    if (!e.reading) {
        e.reading = 0;
        dispatch_suspend(e.rev);
    }
}

static void redisLibdispatchAddWrite(void *privdata) {
    RedisLibDispatchEvents *e = (__bridge RedisLibDispatchEvents*)privdata;
    if (!e.writing) {
        e.writing = 1;
        dispatch_resume(e.wev);
    }
}

static void redisLibdispatchDelWrite(void *privdata) {
    RedisLibDispatchEvents *e = (__bridge RedisLibDispatchEvents*)privdata;
    if (e.writing) {
        e.writing = 0;
        dispatch_suspend(e.wev);
    }
}

static void redisLibdispatchCleanup(void *privdata) {
    RedisLibDispatchEvents *e = (__bridge RedisLibDispatchEvents*)privdata;
    
    if (e.rev != NULL && dispatch_source_testcancel(e.rev) == 0) {
        redisLibdispatchAddRead(privdata);
        dispatch_source_cancel(e.rev);
    }
    
    if (e.wev != NULL && dispatch_source_testcancel(e.wev) == 0) {
        redisLibdispatchAddWrite(privdata);
        dispatch_source_cancel(e.wev);
    }
}

#endif  // __HIREDIS_LIBDISPATCH_H__
