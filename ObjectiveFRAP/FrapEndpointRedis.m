//
//  FrapEndpointRedis.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 4/22/14.
//  Copyright (c) 2014 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpointRedis.h"
#import "DDLog.h"
#import "hiredis-libdispatch.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@interface FrapEndpointRedis ()

+(NSMutableDictionary *)endpointDictionary;
+(void)registerEndpoint:(FrapEndpointRedis *)endpoint withContext:(redisAsyncContext *)context;
+(FrapEndpointRedis *)endpointForContext:(const struct redisAsyncContext *)context;
+(void)deregisterEndpointWithContext:(redisAsyncContext *)context;

-(void)redisContextDidConnect:(const struct redisAsyncContext *)c status:(int)status;
-(void)redisContextDidDisconnect:(const struct redisAsyncContext *)c status:(int)status;
-(void)sendRedisCommand:(NSArray *)args usingContext:(redisAsyncContext *)context andThen:(void (^)(redisReply *))block;
-(void)sendRedisCommand:(NSArray *)args andThen:(void (^)(redisReply *))block;

-(id)interpretRedisReply:(redisReply *)reply;
@end

@implementation FrapEndpointRedis

void redisContextDidConnect(const struct redisAsyncContext *context, int status) {
    [[FrapEndpointRedis endpointForContext:context] redisContextDidConnect:context status:status];
}

void redisContextDidDisconnect(const struct redisAsyncContext *context, int status) {
    [[FrapEndpointRedis endpointForContext:context] redisContextDidDisconnect:context status:status];
}

void redisCommandCallback(redisAsyncContext *context, void *reply, void *privdata) {
    void (^block)(redisReply *) = (__bridge void (^)(redisReply *))privdata;
    block((redisReply *)reply);
}

+(NSMutableDictionary *)endpointDictionary {
    static dispatch_once_t onceToken;
    static NSMutableDictionary *endpointsByRedisContext = nil;
    
    dispatch_once(&onceToken, ^{
        endpointsByRedisContext = [NSMutableDictionary dictionary];
    });
    return endpointsByRedisContext;
}

+(void)registerEndpoint:(FrapEndpointRedis *)endpoint withContext:(redisAsyncContext *)context {
    NSMutableDictionary *endpointDictionary = [self endpointDictionary];
    
    @synchronized(endpointDictionary) {
        [endpointDictionary setObject:endpoint forKey:[NSValue valueWithPointer:context]];
    }
    
    redisAsyncSetConnectCallback(context, redisContextDidConnect);
    redisAsyncSetDisconnectCallback(context, redisContextDidDisconnect);
}

+(FrapEndpointRedis *)endpointForContext:(const struct redisAsyncContext *)context {
    NSMutableDictionary *endpointDictionary = [self endpointDictionary];
    
    @synchronized(endpointDictionary) {
        return [endpointDictionary objectForKey:[NSValue valueWithPointer:context]];
    }
}

+(void)deregisterEndpointWithContext:(redisAsyncContext *)context {
    NSMutableDictionary *endpointDictionary = [self endpointDictionary];
    
    @synchronized(endpointDictionary) {
        [endpointDictionary removeObjectForKey:[NSValue valueWithPointer:context]];
    }
}

-(BOOL)connect:(NSError *__autoreleasing *)error {
    DDLogInfo(@"Connecting to Redis server...");
    commandContext = redisAsyncConnect("127.0.0.1", 6379);
    commandLibDispatchEvents = [[RedisLibDispatchEvents alloc] initWithContext:commandContext queue:dispatch_get_main_queue()];
    
    pubsubContext = redisAsyncConnect("127.0.0.1", 6379);
    pubsubLibDispatchEvents = [[RedisLibDispatchEvents alloc] initWithContext:pubsubContext queue:dispatch_get_main_queue()];
    
    BOOL (^registerEndpointIfConnected)(redisAsyncContext *) = ^BOOL(redisAsyncContext *context) {
        if (context->err) {
            *error = [NSError errorWithDomain:@"org.aegames" code:pubsubContext->err userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString([NSString stringWithCString:pubsubContext->errstr encoding:NSASCIIStringEncoding], @"")}];
            return NO;
        } else {
            [self.class registerEndpoint:self withContext:pubsubContext];
            
            return YES;
        }
    };
    
    if (registerEndpointIfConnected(commandContext)) {
        if (registerEndpointIfConnected(pubsubContext)) {
            return YES;
        } else {
            [self.class deregisterEndpointWithContext:commandContext];
            redisAsyncDisconnect(commandContext);
        }
    }
    
    return NO;
}

-(void)sendRedisCommand:(NSArray *)args usingContext:(redisAsyncContext *)context andThen:(void (^)(redisReply *))block {
    char **argArray = malloc(sizeof(char *) * args.count);
    size_t *argvlen = malloc(sizeof(size_t) * args.count);
    
    int i = 0;
    for (id arg in args) {
        NSData *data;
        if ([arg isKindOfClass:[NSString class]]) {
            data = [arg dataUsingEncoding:NSASCIIStringEncoding];
        } else if ([arg isKindOfClass:[NSData class]]) {
            data = arg;
        }
        
        const void *cString = [data bytes];
        size_t length = [data length];
        char *copy = malloc(sizeof(char) * length);
        strcpy(copy, cString);
        
        argArray[i] = copy;
        argvlen[i++] = length;
    }
    
    redisAsyncCommandArgv(context, redisCommandCallback, (__bridge_retained void *)(block), (int)args.count, (const char**)argArray, argvlen);
    
    for (i = 0; i < args.count; i++) {
        free(argArray[i]);
    }
    
    free(argArray);
    free(argvlen);
}

-(void)sendRedisCommand:(NSArray *)args andThen:(void (^)(redisReply *))block {
    [self sendRedisCommand:args usingContext:commandContext andThen:block];
}

-(void)sendData:(NSData *)data {
    [self sendRedisCommand:@[@"publish", @"foh:frap", data] andThen:^(redisReply *reply) {
        
    }];
}

-(void)redisContextDidConnect:(const struct redisAsyncContext *)c status:(int)status {
    DDLogInfo(@"Subscribing to channel");
    
    [self sendRedisCommand:@[@"SUBSCRIBE", @"foh:frap"] usingContext:pubsubContext andThen:^(redisReply *reply) {
        NSArray *replyArray = [self interpretRedisReply:reply];
        
        if ([(NSString *)replyArray[0] isEqualToString:@"subscribe"]) {
            [self.connectionDelegate frapEndpointDidConnect:self];
            [self startStatusLoop];

            FrapStatusRequestMessage *statusRequest = [[FrapStatusRequestMessage alloc] init];
            statusRequest.objectIds = @[].mutableCopy;
            [self sendFrapMessage:statusRequest];
        } else {
            FrapMessage *msg = [FrapMessage decodeFrapMessage:replyArray[2]];
            [self didReceiveFrapMessage:msg];
        }
    }];
}

-(void)redisContextDidDisconnect:(const struct redisAsyncContext *)c status:(int)status {
    DDLogWarn(@"Redis disconnected with status %d, trying to reconnect...", status);
    
    [self connect:nil];
}

-(id)interpretRedisReply:(redisReply *)reply {
    NSMutableArray *array;
    
    if (reply == nil)
        return nil;
    
    switch (reply->type) {
        case REDIS_REPLY_STATUS:
        case REDIS_REPLY_ERROR:
        case REDIS_REPLY_STRING:
            return [NSString stringWithCString:reply->str encoding:NSASCIIStringEncoding];
            
        case REDIS_REPLY_INTEGER:
            return [NSNumber numberWithLongLong:reply->integer];
            
        case REDIS_REPLY_ARRAY:
            array = [NSMutableArray arrayWithCapacity:reply->elements];
            for (int i=0; i<reply->elements; i++) {
                array[i] = [self interpretRedisReply:reply->element[i]];
            }
            return array;
    }
    
    return nil;
}

-(void)disconnect {
    [self.class deregisterEndpointWithContext:pubsubContext];
    [self.class deregisterEndpointWithContext:commandContext];
    
    redisAsyncDisconnect(pubsubContext);
    redisAsyncDisconnect(commandContext);
}

@end
