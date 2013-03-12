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
#import "GCDAsyncUdpSocket.h"
#import "Reachability.h"

@interface FrapEndpoint : NSObject {
	NSString *__unsafe_unretained endpointId;
	id<FrapEndpointDelegate> __unsafe_unretained delegate;
}

@property (nonatomic, unsafe_unretained) NSString *endpointId;
@property (nonatomic, unsafe_unretained) NSString *frdlRole;
@property (nonatomic, unsafe_unretained) IBOutlet id<FrapEndpointDelegate> delegate;
@property (nonatomic, unsafe_unretained) IBOutlet id<FrapEndpointConnectionDelegate> connectionDelegate;
@property (nonatomic, readonly) NSMutableDictionary *sharedObjects;

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

-(void)startStatusLoop;
-(void)stopStatusLoop;

-(void)addObserver:(NSObject *)observer forSharedObject:(NSString *)key options:(NSKeyValueObservingOptions)options;

@end
