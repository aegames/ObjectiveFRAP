//
//  FrapEndpoint.h
//  libfrap
//
//  Created by Nat Budin on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FrapMessages.h"
#import "FrapEndpointDelegate.h"
#import "FrapEndpointConnectionDelegate.h"
#import "Reachability.h"

@interface FrapEndpoint : NSObject

@property NSString *endpointId;
@property NSString *frdlRole;
@property (nonatomic) IBOutlet id<FrapEndpointDelegate> delegate;
@property (nonatomic) IBOutlet id<FrapEndpointConnectionDelegate> connectionDelegate;
@property (readonly) NSMutableDictionary *sharedObjects;

+(FrapEndpoint *)sharedEndpoint;

-(id)init;

-(void)startNetworking;
-(BOOL)connect:(NSError **)error;
-(void)disconnect;
-(BOOL)isConnected;

-(Reachability *)reachability;

-(void)sendFrapMessage:(FrapMessage *)msg;
-(void)sendData:(NSData *)data;
-(void)didReceiveFrapMessage:(FrapMessage *)msg;

-(void)setSharedObjectAtKey:(NSString *)key toValue:(NSObject *)value;
-(void)setSharedObjectAtKey:(NSString *)key toValue:(NSObject *)value sendMessage:(BOOL)sendMessage;
-(NSObject *)sharedObjectValueForKey:(NSString *)key;
-(NSEnumerator *)sharedObjectKeys;

-(void)addObserver:(NSObject *)observer forSharedObject:(NSString *)key options:(NSKeyValueObservingOptions)options;

- (FrapStatusUpdateMessage*)statusUpdateMessageForSharedObjectKeys: (NSArray*)keys;

- (NSArray*)ownedSharedObjectKeys;

@end
