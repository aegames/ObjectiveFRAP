//
//  FrapEndpointUDP.h
//  ObjectiveFRAP
//
//  Created by Nat Budin on 3/12/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpoint.h"

@interface FrapEndpointUDP : FrapEndpoint<GCDAsyncUdpSocketDelegate> {
    GCDAsyncUdpSocket *listenSocket;
    GCDAsyncUdpSocket *sendSocket;
    NSLock *sendLock;
}

@end
