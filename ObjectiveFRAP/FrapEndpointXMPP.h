//
//  FrapEndpointXMPP.h
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/13/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpoint.h"
#import "XMPPFramework.h"

@interface FrapEndpointXMPP : FrapEndpoint<XMPPStreamDelegate, XMPPReconnectDelegate, XMPPMUCDelegate, XMPPRoomDelegate> {
    XMPPStream *xmppStream;
    XMPPReconnect *reconnect;
    XMPPMUC *muc;
    
    XMPPRoom *room;
    NSObject<XMPPRoomStorage> *roomStorage;
    NSString *groupChatDomain;
}

@end
