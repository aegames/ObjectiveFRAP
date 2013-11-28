//
//  AppDelegate.h
//  FRAPConsole
//
//  Created by Nat Budin on 11/26/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FrapEndpoint.h"
#import "FrapEndpointConnectionDelegate.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, FrapEndpointConnectionDelegate> {
    FrapEndpoint *endpoint;
}

@property (assign) IBOutlet NSWindow *window;

@end
