//
//  FRAPConsole.eeh
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/13/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FrapEndpointDelegate.h"
#import "FrapEndpointConnectionDelegate.h"
#import "FCLogger.h"

@interface FCWindow: NSWindow<FrapEndpointDelegate, NSTextViewDelegate, NSTextFieldDelegate> {
    NSMutableArray *commandHistory;
    int commandHistoryPosition;
    NSString *savedCurrentCommand;
}

@property IBOutlet NSTextField *commandPrompt;
@property IBOutlet NSTextView *logView;
@property (readonly) FCLogger *logger;

-(IBAction)sendCommand:(id)sender;

@end
