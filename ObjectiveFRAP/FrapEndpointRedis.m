//
//  FrapEndpointRedis.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 4/22/14.
//  Copyright (c) 2014 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpointRedis.h"
#import "hiredis-libdispatch.h"
#import "FrdlParser.h"
#import <BlocksKit/BlocksKit.h>

@interface FrapEndpointRedis ()

+(NSMutableDictionary *)endpointDictionary;
+(void)registerEndpoint:(FrapEndpointRedis *)endpoint withContext:(redisAsyncContext *)context;
+(FrapEndpointRedis *)endpointForContext:(const struct redisAsyncContext *)context;
+(void)deregisterEndpointWithContext:(redisAsyncContext *)context;

-(void)connectToRedis;
-(void)redisContextDidConnect:(const struct redisAsyncContext *)c status:(int)status;
-(void)redisContextDidDisconnect:(const struct redisAsyncContext *)c status:(int)status;
-(void)sendRedisCommand:(NSArray *)args usingContext:(redisAsyncContext *)context andThen:(void (^)(redisReply *))block;
-(void)sendRedisCommand:(NSArray *)args andThen:(void (^)(redisReply *))block;
-(void)redisContextRepliedWithError:(const struct redisAsyncContext *)c;
-(void)disconnectWithError:(NSError *)error;
-(id)interpretRedisReply:(redisReply *)reply withContext:(const struct redisAsyncContext *)context;

-(void)loadSharedObjectValues;
-(NSString *)redisKeyForSharedObjectKey:(NSString *)key;

@end

@implementation FrapEndpointRedis
@synthesize isConnected;

void redisContextDidConnect(const struct redisAsyncContext *context, int status) {
    [[FrapEndpointRedis endpointForContext:context] redisContextDidConnect:context status:status];
}

void redisContextDidDisconnect(const struct redisAsyncContext *context, int status) {
    [[FrapEndpointRedis endpointForContext:context] redisContextDidDisconnect:context status:status];
}

void redisCommandCallback(redisAsyncContext *context, void *reply, void *privdata) {
    if (reply) {
        void (^block)(redisReply *) = (__bridge void (^)(redisReply *))privdata;
        if (block) {
            block((redisReply *)reply);
        }
    } else {
        [[FrapEndpointRedis endpointForContext:context] redisContextRepliedWithError:context];
    }
}

-(id)init {
    serviceBrowser = [[NSNetServiceBrowser alloc] init];
    servicesToResolve = [NSMutableSet set];
    servicesResolved = [NSMutableSet set];
    self.isConnected = NO;
    return [super init];
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
    serviceBrowser.delegate = self;
    [serviceBrowser searchForServicesOfType:@"_redis._tcp" inDomain:@""];
    [self.connectionDelegate frapEndpointWillConnect:self];
    
    browseTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    
    dispatch_source_set_event_handler(browseTimer, ^{ @autoreleasepool {
        [serviceBrowser stop];
        [self.connectionDelegate frapEndpoint:self didNotConnectWithError:[NSError errorWithDomain:@"org.aegames" code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Failed to find any Redis servers", @"")}]];
    }});
    
    dispatch_source_t theBrowseTimer = browseTimer;
    dispatch_source_set_cancel_handler(browseTimer, ^{
        dispatch_release(theBrowseTimer);
    });
    
    dispatch_source_set_timer(browseTimer, dispatch_time(DISPATCH_TIME_NOW, (5.0 * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 0);
    
    dispatch_resume(browseTimer);
    
    return YES;
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    
    if (browseTimer) {
        dispatch_source_cancel(browseTimer);
        browseTimer = nil;
    }
    
    if ([aNetService.name isEqualToString:@"foh-redis"]) {
        [self.connectionDelegate frapEndpoint:self connectionStatusChangedTo:[NSString stringWithFormat:@"Found service %@ on %@", aNetService.name, aNetService.domain]];
        
        @synchronized(servicesToResolve) {
            [servicesToResolve addObject:aNetService];
        }
        aNetService.delegate = self;
    }
    
    if (!moreComing) {
        @synchronized(servicesToResolve) {
            for (NSNetService *service in servicesToResolve) {
                [service resolveWithTimeout:5.0];
            }
        }
    }
}

-(void)netServiceDidResolveAddress:(NSNetService *)aNetService {
    [self.connectionDelegate frapEndpoint:self connectionStatusChangedTo:[NSString stringWithFormat:@"Resolved service %@ on %@:%ld", aNetService.name, aNetService.hostName, aNetService.port]];
    
    @synchronized(servicesToResolve) {
        [servicesToResolve removeObject:aNetService];
        [servicesResolved addObject:aNetService];
    }
    
    if (servicesToResolve.count == 0) {
        [self connectToRedis];
    }
}

-(void)connectToRedis {
    @synchronized(servicesResolved) {
        if (self.isConnected) {
            return;
        }
        
        if (servicesResolved.count == 0) {
            [self.connectionDelegate frapEndpoint:self didNotConnectWithError:[NSError errorWithDomain:@"org.aegames" code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"No Redis server found", @"")}]];
            
            return;
        }
        
        NSNetService *bestService;
        for (NSNetService *service in servicesResolved) {
            if (bestService == nil) {
                bestService = service;
            } else if ([service.domain isEqualToString:@"local."]) {
                bestService = service;
            }
        }
        
        const char *hostName = [bestService.hostName cStringUsingEncoding:NSUTF8StringEncoding];
        int port = (int)bestService.port;
        
        [self.connectionDelegate frapEndpoint:self connectionStatusChangedTo:[NSString stringWithFormat:@"Connecting to Redis server on %s:%d", hostName, port]];
        commandContext = redisAsyncConnect(hostName, port);
        commandLibDispatchEvents = [[RedisLibDispatchEvents alloc] initWithContext:commandContext queue:dispatch_get_main_queue()];
        
        pubsubContext = redisAsyncConnect(hostName, port);
        pubsubLibDispatchEvents = [[RedisLibDispatchEvents alloc] initWithContext:pubsubContext queue:dispatch_get_main_queue()];
        
        BOOL (^registerEndpointIfConnected)(redisAsyncContext *) = ^BOOL(redisAsyncContext *context) {
            if (context->err) {
                [self.connectionDelegate frapEndpoint:self didNotConnectWithError:[NSError errorWithDomain:@"org.aegames" code:pubsubContext->err userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString([NSString stringWithCString:pubsubContext->errstr encoding:NSUTF8StringEncoding], @"")}]];
                return NO;
            } else {
                [self.class registerEndpoint:self withContext:pubsubContext];
                
                return YES;
            }
        };
        
        if (registerEndpointIfConnected(commandContext)) {
            if (registerEndpointIfConnected(pubsubContext)) {
                return;
            } else {
                [self.class deregisterEndpointWithContext:commandContext];
                redisAsyncDisconnect(commandContext);
            }
        }
    }
    
    redisAsyncFree(commandContext);
    redisAsyncFree(pubsubContext);
    commandContext = nil;
    pubsubContext = nil;
}

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    @synchronized(servicesToResolve) {
        [servicesToResolve removeObject:sender];
    }
    
    if (servicesToResolve.count == 0) {
        [self connectToRedis];
    }
}

-(void)sendRedisCommand:(NSArray *)args usingContext:(redisAsyncContext *)context andThen:(void (^)(redisReply *))block {
    char **argArray = malloc(sizeof(char *) * args.count);
    size_t *argvlen = malloc(sizeof(size_t) * args.count);
    
    int i = 0;
    for (id arg in args) {
        NSData *data;
        if ([arg isKindOfClass:[NSString class]]) {
            data = [arg dataUsingEncoding:NSUTF8StringEncoding];
        } else if ([arg isKindOfClass:[NSData class]]) {
            data = arg;
        }
        
        const void *cString = [data bytes];
        size_t length = [data length];
        char *copy = malloc(sizeof(char) * (length + 1));
        memcpy(copy, cString, length);
        copy[length] = '\0';
        
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
    if (c == pubsubContext) {
        [self.connectionDelegate frapEndpoint:self connectionStatusChangedTo:@"Subscribing to message channel"];
        
        [self sendRedisCommand:@[@"SUBSCRIBE", @"foh:frap"] usingContext:(redisAsyncContext *)c andThen:^(redisReply *reply) {
            NSArray *replyArray = [self interpretRedisReply:reply withContext:c];
            
            if ([(NSString *)replyArray[0] isEqualToString:@"subscribe"]) {
                self.isConnected = YES;
                [self.connectionDelegate frapEndpointDidConnect:self];
                [self loadSharedObjectValues];
            } else {
                FrapMessage *msg = [FrapMessage decodeFrapMessage:replyArray[2]];
                [self didReceiveFrapMessage:msg];
            }
        }];
    }
}

-(void)redisContextDidDisconnect:(const struct redisAsyncContext *)c status:(int)status {
    [self disconnect];
}

-(void)redisContextRepliedWithError:(const struct redisAsyncContext *)c {
    if (c->err == REDIS_ERR_IO) {
        [self disconnectWithError:[NSError errorWithDomain:@"io.redis" code:errno userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString([NSString stringWithCString:strerror(errno) encoding:NSUTF8StringEncoding], @"")}]];
    } else {
        NSLog(@"Redis replied with error %d: %s", c->err, c->errstr);
    }
}

-(id)interpretRedisReply:(redisReply *)reply withContext:(const struct redisAsyncContext *)context {
    NSMutableArray *array;
    
    if (reply == nil)
        return nil;
    
    switch (reply->type) {
        case REDIS_REPLY_ERROR:
            return [NSError errorWithDomain:@"io.redis" code:context->err userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString([NSString stringWithCString:reply->str encoding:NSUTF8StringEncoding], @"")}];
        
        case REDIS_REPLY_STATUS:
        case REDIS_REPLY_STRING:
            return [NSString stringWithCString:reply->str encoding:NSUTF8StringEncoding];
            
        case REDIS_REPLY_INTEGER:
            return [NSNumber numberWithLongLong:reply->integer];
            
        case REDIS_REPLY_ARRAY:
            array = [NSMutableArray arrayWithCapacity:reply->elements];
            for (int i=0; i<reply->elements; i++) {
                id element = [self interpretRedisReply:reply->element[i] withContext:context];
                
                if (element) {
                    array[i] = element;
                } else {
                    array[i] = [NSNull null];
                }
            }
            return array;
    }
    
    return nil;
}

-(NSString *)redisKeyForSharedObjectKey:(NSString *)key {
    return [NSString stringWithFormat:@"foh:shared_object:%@", key];
}

-(void)loadSharedObjectValues {
    NSArray *keys = [self.ownedSharedObjectKeys bk_map:^id(id obj) {
        return [self redisKeyForSharedObjectKey:obj];
    }];
    if (keys.count == 0) {
        return;
    }
    
    [self sendRedisCommand:[@[@"MGET"] arrayByAddingObjectsFromArray:keys] andThen:^(redisReply *reply) {
        NSArray *values = [self interpretRedisReply:reply withContext:commandContext];
        
        NSEnumerator *keyEnumerator = [keys objectEnumerator];
        for (id value in values) {
            NSString *key = [keyEnumerator nextObject];
            
            if ([value isKindOfClass:[NSString class]]) {
                NSString *string = (NSString *)value;
                id valueForKey;
                
                switch ([[FrdlParser sharedParser] sharedObjectTypeForKey:key]) {
                    case FrapNumber:
                        valueForKey = [NSNumber numberWithFloat:[string floatValue]];
                        break;
                    default:
                        valueForKey = string;
                }
                
                [self setSharedObjectAtKey:key toValue:valueForKey sendMessage:NO];
            } else {
                // it's NSNull; save the default to Redis
                [self setSharedObjectAtKey:key toValue:[self sharedObjectValueForKey:key] sendMessage:YES];
            }
        }
    }];
}

-(void)setSharedObjectAtKey:(NSString *)key toValue:(NSObject *)value sendMessage:(BOOL)sendMessage {
    if (sendMessage) {
        NSString *valueString;
        NSNumber *numberValue;
        
        switch ([[FrdlParser sharedParser] sharedObjectTypeForKey:key]) {
            case FrapNumber:
                numberValue = (NSNumber *)value;
                valueString = [numberValue stringValue];
                break;
            default:
                valueString = (NSString *)value;
                break;
        }
        
        [self sendRedisCommand:@[@"SET", [self redisKeyForSharedObjectKey:key], valueString] andThen:nil];
    }
    
    [super setSharedObjectAtKey:key toValue:value sendMessage:sendMessage];
}

-(void)disconnectWithError:(NSError *)error {
    self.isConnected = NO;
    [self.class deregisterEndpointWithContext:pubsubContext];
    [self.class deregisterEndpointWithContext:commandContext];
    
    redisAsyncDisconnect(pubsubContext);
    redisAsyncDisconnect(commandContext);
    
    [self.connectionDelegate frapEndpoint:self didDisconnectWithError:error];
}

-(void)disconnect {
    [self disconnectWithError:nil];
}

@end
