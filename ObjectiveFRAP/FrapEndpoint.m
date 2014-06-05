//
//  FrapEndpoint.m
//  libfrap
//
//  Created by Nat Budin on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#import "FrapEndpoint.h"
#import "FrapSharedObject.h"
#import "FrdlParser.h"

@interface FrapEndpoint () {
    NSDictionary *sharedObjectLocks;
    NSLock *sharedObjectDictionaryLock;
    NSString *subscriptionRequestSid;
    
    __strong Reachability *reachability;
}

#if TARGET_OS_IPHONE
-(void)reachabilityChanged:(NSNotification *)note;
#endif
-(FrapSharedObject *)sharedObjectForKey:(NSString *)key;
@end

@implementation FrapEndpoint
@synthesize endpointId, delegate, frdlRole;

-(BOOL)connect:(NSError *__autoreleasing *)error {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

-(void)disconnect {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

-(BOOL)isConnected {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

-(Reachability *)reachability {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

-(void)sendData:(NSData *)data {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)] userInfo:nil];
}

+(FrapEndpoint *)sharedEndpoint {
    __strong static FrapEndpoint *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (sharedInstance == nil) {
            sharedInstance = [[self alloc] init];
        }
    });
        
    return sharedInstance;
}

-(FrapEndpoint *)init {
    self = [super init];
    
    _sharedObjects = [[NSMutableDictionary alloc] init];
    sharedObjectLocks = [[NSMutableDictionary alloc] init];
    
    [[FrdlParser sharedParser] parseGameFrdl];
    [[FrdlParser sharedParser] setDefaultsForFrapEndpoint:self sendMessages:NO];
        
	return self;
}

-(void)dealloc {
    [self disconnect];
}

-(void)startNetworking {
    reachability = [self reachability];
    [reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    if ([reachability isReachable]) {
        NSError *error = [[NSError alloc] init];
        
        if (![self connect:&error]) {
            NSLog(@"%@ had error connecting: %@", self, error);
        }
    }
}

-(void)reachabilityChanged:(NSNotification *)note {
    Reachability *curReach = [note object];
    if ([curReach isReachable]) {
        NSError *error = [[NSError alloc] init];
        if (![self connect:&error]) {
            NSLog(@"%@ had error connecting: %@", self, error);
        }
    } else {
        [self disconnect];
    }
}

-(void)sendFrapMessage:(FrapMessage *)msg {
    msg.sender = endpointId;
	NSData *data = [msg encode];
    NSLog(@"Prepared FRAP message %@", msg);

    [self sendData:data];
	
	if ([delegate respondsToSelector:@selector(didSendFrapMessage:)]) {
		[delegate didSendFrapMessage:msg];
	}
}

-(void)didReceiveFrapMessage:(FrapMessage *)msg {
    // ignore messages from self
    if ([[msg sender] isEqualToString:endpointId]) {
        return;
    }
    
    NSLog(@"Received FRAP message %@", msg);
    
	if ([delegate respondsToSelector:@selector(didReceiveFrapMessage:)]) {
		[delegate didReceiveFrapMessage:msg];
	}
    
	if ([msg isKindOfClass:[FrapIdentityRequestMessage class]]) {
		[self sendFrapMessage:[[FrapIdentityMessage alloc] init]];
	} else if ([msg isKindOfClass:[FrapSetSharedObjectMessage class]]) {
        FrapSetSharedObjectMessage *setObject = (FrapSetSharedObjectMessage *)msg;
        [self setSharedObjectAtKey:setObject.key toValue:setObject.value sendMessage:NO];
    } else if ([msg isKindOfClass:[FrapStatusUpdateMessage class]]) {
        FrapStatusUpdateMessage *statusUpdate = (FrapStatusUpdateMessage *)msg;
        for (NSString *key in statusUpdate.objects.keyEnumerator) {
            [self setSharedObjectAtKey:key toValue:[statusUpdate.objects valueForKey:key] sendMessage:NO];
        }
    } else if ([msg isKindOfClass:[FrapStatusRequestMessage class]]) {
        FrapStatusRequestMessage *statusRequest = (FrapStatusRequestMessage *)msg;
        FrapStatusUpdateMessage *reply = [[FrapStatusUpdateMessage alloc] init];
        
        NSArray *objectIds;
        if (statusRequest.objectIds.count > 0) {
            objectIds = statusRequest.objectIds;
        } else {
            objectIds = [[self sharedObjectKeys] allObjects];
        }
    
        NSMutableDictionary *objectValues = [[NSMutableDictionary alloc] initWithCapacity:objectIds.count];
        for (NSString *key in objectIds) {
            [objectValues setValue:[self sharedObjectValueForKey:key] forKey:key];
        }
    
        reply.objects = objectValues;
        [self sendFrapMessage:reply];
    }
}

-(NSEnumerator *)sharedObjectKeys {
    return [self.sharedObjects keyEnumerator];
}

-(NSObject *)sharedObjectValueForKey:(NSString *)key {
    return [[self sharedObjectForKey:key] value];
}

-(FrapSharedObject *)sharedObjectForKey:(NSString *)key {
    [sharedObjectDictionaryLock lock];
    FrapSharedObject *sharedObject = [self.sharedObjects valueForKey:key];
    if (sharedObject == nil) {
        sharedObject = [[FrapSharedObject alloc] initWithEndpoint:self key:key];
        [self.sharedObjects setValue:sharedObject forKey:key];
    }
    [sharedObjectDictionaryLock unlock];
    
    return sharedObject;
}

-(void)setSharedObjectAtKey:(NSString *)key toValue:(NSObject *)value {
    [self setSharedObjectAtKey:key toValue:value sendMessage:YES];
}

-(void)setSharedObjectAtKey:(NSString *)key toValue:(NSObject *)value sendMessage:(BOOL)sendMessage {
    NSObject *previousValue = [self sharedObjectValueForKey:key];
    if ([previousValue isEqual:value])
        return;
    
    [[self sharedObjectForKey:key] setValue:value];
    
    if (sendMessage)
        [self sendFrapMessage:[[FrapSetSharedObjectMessage alloc] initWithKey:key value:value previousValue:previousValue]];
}

-(void)addObserver:(NSObject *)observer forSharedObject:(NSString *)key options:(NSKeyValueObservingOptions)options {
    FrapSharedObject *obj = [self sharedObjectForKey:key];
    [obj addObserver:self forKeyPath:@"value" options:options context:(__bridge void *)(observer)];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context && [keyPath isEqualToString:@"value"] && [object isKindOfClass:[FrapSharedObject class]]) {
        NSObject *observer = (__bridge NSObject *)context;
        FrapSharedObject *sharedObject = (FrapSharedObject *)object;
        
        [observer observeValueForKeyPath:sharedObject.key ofObject:self.sharedObjects change:change context:nil];
    }
}

- (FrapStatusUpdateMessage *)statusUpdateMessageForSharedObjectKeys:(NSArray *)keys {
    FrapStatusUpdateMessage *msg = [[FrapStatusUpdateMessage alloc] init];
    NSMutableDictionary *objects = [[NSMutableDictionary alloc] initWithCapacity:[keys count]];
    
    for (NSString *key in keys) {
        [objects setValue:[self sharedObjectValueForKey:key] forKey:key];
    }
    
    msg.objects = objects;
    return msg;
}

- (NSArray *)ownedSharedObjectKeys {
    if (self.frdlRole == nil) {
        return @[];
    } else {
        return [[FrdlParser sharedParser] sharedObjectsOwnedByRole:self.frdlRole];
    }
}

@end
