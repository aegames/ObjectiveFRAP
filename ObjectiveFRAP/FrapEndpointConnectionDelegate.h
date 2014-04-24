//
//  FrapEndpointConnectionDelegate.h
//  FRAP
//
//  Created by Nat Budin on 12/28/12.
//  Copyright (c) 2012 Alleged Entertainment. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FrapEndpointConnectionDelegate <NSObject>

@optional
-(void)frapEndpointWillConnect:(id)endpoint;
-(void)frapEndpoint:(id)endpoint connectionStatusChangedTo:(NSString *)status;
-(void)frapEndpointDidConnect:(id)endpoint;
-(void)frapEndpoint:(id)endpoint didNotConnectWithError:(NSError *)error;
-(void)frapEndpoint:(id)endpoint didDisconnectWithError:(NSError *)error;

@end
