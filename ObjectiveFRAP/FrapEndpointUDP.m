//
//  FrapEndpointUDP.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 3/12/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpointUDP.h"

@interface FrapEndpointUDP () {
    BOOL udpBound;
    long tag;
}
@end

@implementation FrapEndpointUDP

-(id)init {
    self = [super init];
    sendLock = [[NSLock alloc] init];
    udpBound = NO;
    return self;
}

-(BOOL)isConnected {
    return udpBound;
}

-(BOOL)connect:(NSError **)error {
    tag = 0;
    
    listenSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    sendSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    if (![listenSocket bindToPort:23952 error:error])
        return FALSE;
    if (![listenSocket enableBroadcast:TRUE error:error])
        return FALSE;
    
	if (![listenSocket joinMulticastGroup:@"224.23.95.2" error:error])
		return FALSE;
    
    if (![sendSocket connectToHost:@"224.23.95.2" onPort:23952 error:error])
        return FALSE;
    
    if (![sendSocket enableBroadcast:TRUE error:error])
        return FALSE;
    
    [listenSocket beginReceiving:error];
    
    udpBound = YES;
    
    [self startStatusLoop];
	
	return TRUE;
}

-(void)disconnect {
    [self stopStatusLoop];
    
    [listenSocket close];
    
    listenSocket.delegate = nil;
    listenSocket = nil;
    
    [sendSocket closeAfterSending];
    
    sendSocket.delegate = nil;
    sendSocket = nil;
    
    udpBound = NO;
}

-(void)sendData:(NSData *)data {
    [sendLock lock];
    [sendSocket sendData:data withTimeout:-1 tag:tag];
    
    if (tag == LONG_MAX)
        tag = 0;
    else
        tag++;
    
	[sendLock unlock];
}

-(Reachability *)reachability {
    return [Reachability reachabilityForLocalWiFi];
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
	
	NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	FrapMessage *msg = [FrapMessage decodeFrapMessage:dataStr];
	
	[self didReceiveFrapMessage:msg];
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    NSLog(@"Connected to %@:%hu", [GCDAsyncUdpSocket hostFromAddress:address], [GCDAsyncUdpSocket portFromAddress:address]);
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NSLog(@"Failed to connect: %@", error);
}

-(void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NSLog(@"UDP socket closed: %@", error);
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)t {
    NSLog(@"Sent data with tag %ld", t);
}

-(void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)t dueToError:(NSError *)error {
    NSLog(@"Failed to send data with tag %ld due to %@", t, error);
}

@end
