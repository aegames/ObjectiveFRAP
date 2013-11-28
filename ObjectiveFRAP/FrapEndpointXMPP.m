//
//  FrapEndpointXMPP.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/13/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "FrapEndpointXMPP.h"
#import "DDXML.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation FrapEndpointXMPP

-(BOOL)connect:(NSError **)error {
    xmppStream = [[XMPPStream alloc] init];
    xmppStream.myJID = [XMPPJID jidWithString:[NSString stringWithFormat: @"%@@%@", self.endpointId, @"puck"]];
    xmppStream.hostName = @"127.0.0.1";
    [xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    reconnect = [[XMPPReconnect alloc] init];
    [reconnect activate:xmppStream];
    [reconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    muc = [[XMPPMUC alloc] init];
    [muc activate:xmppStream];
    [muc addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    roomStorage = [[XMPPRoomMemoryStorage alloc] init];
    
    if (![xmppStream connectWithTimeout:1.0 error:error])
        return NO;

    return YES;
}

-(void)disconnect {
    [xmppStream disconnect];
    [xmppStream removeDelegate:self];
}

-(void)xmppStreamWillConnect:(XMPPStream *)sender {
    DDLogInfo(@"Connecting to XMPP server");
}

-(void)xmppStreamConnectDidTimeout:(XMPPStream *)sender {
    DDLogError(@"Connection timed out");
}

-(void)xmppStream:(XMPPStream *)sender didReceiveError:(DDXMLElement *)error {
    DDLogError(@"XMPP error!\n%@", error);
}

-(void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket {
    DDLogInfo(@"Socket connected");
}

-(void)xmppStreamDidStartNegotiation:(XMPPStream *)sender {
    DDLogInfo(@"Started negotiation");
}

-(void)xmppStreamDidConnect:(XMPPStream *)sender {
    DDLogInfo(@"Connected to XMPP server, authenticating");
    [xmppStream authenticateWithPassword:@"ObjectiveFRAP" error:nil];
}

-(void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error {
    DDLogError(@"XMPP stream disconnected with error: %@", error);
}

-(void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
    DDLogInfo(@"Authentication failed! %@", error);
    DDLogInfo(@"Attempting registration");
    [xmppStream registerWithPassword:@"ObjectiveFRAP" error:nil];
}

-(void)xmppStreamDidRegister:(XMPPStream *)sender {
    [xmppStream authenticateWithPassword:@"ObjectiveFRAP" error:nil];
}

-(void)xmppStream:(XMPPStream *)sender didNotRegister:(DDXMLElement *)error {
    DDLogError(@"Registration failed: %@", error);
}

-(void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    DDLogInfo(@"Fetching server capabilities");
    NSXMLElement *query = [[NSXMLElement alloc] initWithXMLString:@"<query xmlns='http://jabber.org/protocol/disco#items'/>"
                                                            error:nil];
    XMPPIQ *iq = [XMPPIQ iqWithType:@"get"
                                 to:[XMPPJID jidWithString:@"puck"]
                          elementID:[xmppStream generateUUID] child:query];
    [xmppStream sendElement:iq];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    
    if([iq isResultIQ])
    {
        if([iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#items"])
        {
            NSXMLElement *query = [iq childElement];
            NSArray *items = [query children];
            for(NSXMLElement *item in items)
            {
                NSError *error = [[NSError alloc] init];
                NSXMLElement *sendQuery = [[NSXMLElement alloc] initWithXMLString:@"<query xmlns='http://jabber.org/protocol/disco#info'/>"
                                                                            error:&error];
                XMPPIQ *sendIQ = [XMPPIQ iqWithType:@"get"
                                                 to:[XMPPJID jidWithString:[item attributeStringValueForName:@"jid"]]
                                          elementID:[xmppStream generateUUID]
                                              child:sendQuery];
                [xmppStream sendElement:sendIQ];
            }
            return YES;
        }
        else if([iq elementForName:@"query" xmlns:@"http://jabber.org/protocol/disco#info"])
        {
            NSXMLElement *query = [iq childElement];
            NSXMLElement *identity = [query elementForName:@"identity"];
            if([[identity attributeStringValueForName:@"type"] isEqualToString:@"text"])
            {
                groupChatDomain = [NSString stringWithFormat:@"%@.%@", [identity attributeStringValueForName:@"category"], @"puck"];
                
                DDLogInfo(@"Joining chat room");
                room = [[XMPPRoom alloc] initWithRoomStorage:roomStorage jid:[XMPPJID jidWithUser:@"frap"
                                                                                           domain:groupChatDomain resource:endpointId]];
                [room activate:xmppStream];
                [room addDelegate:self delegateQueue:dispatch_get_main_queue()];
                
                [room joinRoomUsingNickname:endpointId history:nil];
                return YES;
            }
        }
    }
    
    return NO;
}

-(void)xmppRoomDidCreate:(XMPPRoom *)sender {
    DDLogInfo(@"Created chat room %@", sender.roomJID);
}

-(void)xmppRoomDidJoin:(XMPPRoom *)sender {
    [self.connectionDelegate frapEndpointDidConnect:self];
    [self startStatusLoop];
}

-(void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkConnectionFlags)connectionFlags {
    DDLogWarn(@"Detected accidental disconnect");
}

-(void)sendFrapMessage:(FrapMessage *)msg {
    [room sendMessageWithBody:[[NSString alloc] initWithData:[msg encode] encoding:NSUTF8StringEncoding]];
}

-(void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromOccupant:(XMPPJID *)occupantJID {
    [self didReceiveFrapMessage:[FrapMessage decodeFrapMessage:message.body]];
}

@end
