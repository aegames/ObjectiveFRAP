//
//  AppDelegate.m
//  FRAPConsole
//
//  Created by Nat Budin on 11/26/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "AppDelegate.h"
#import "FrapEndpointRedis.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "FCWindow.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    FCWindow *mainWindow = (FCWindow *)self.window;
    [DDLog addLogger:mainWindow.logger withLogLevel:LOG_LEVEL_VERBOSE];
    
    endpoint = [FrapEndpointRedis sharedEndpoint];
    endpoint.endpointId = @"FRAPConsole";
    endpoint.connectionDelegate = self;
    
    NSError *error = nil;
    if (![endpoint connect: &error]) {
        DDLogError(@"Error connecting FRAP endpoint: %@", error);
    }
}

-(void)frapEndpointWillConnect:(id)endpoint {
    DDLogInfo(@"FRAP endpoint connecting...");
}

-(void)frapEndpointDidConnect:(id)endpoint {
    DDLogInfo(@"FRAP endpoint connected");
}

-(void)frapEndpoint:(id)endpoint didNotConnectWithError:(NSError *)error {
    DDLogInfo(@"Error connecting FRAP endpoint: %@", error.localizedDescription);
}

-(void)frapEndpoint:(id)endpoint connectionStatusChangedTo:(NSString *)status {
    DDLogInfo(@"[Endpoint] %@", status);
}

-(void)frapEndpoint:(id)endpoint didDisconnectWithError:(NSError *)error {
    if (error) {
        DDLogError(@"FRAP endpoint disconnected: %@", error.localizedDescription);
    } else {
        DDLogInfo(@"FRAP endpoint disconnected");
    }
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
