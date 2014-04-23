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

-(void)frapEndpointDidConnect:(id)endpoint {
    DDLogInfo(@"FRAP endpoint connected");
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
