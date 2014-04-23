//
//  FRAPConsole.eero
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/13/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//
 
#import "FCWindow.h"
#import "FRAPEndpointRedis.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation FCWindow

@synthesize logger = _logger, commandPrompt, logView;

-(void)awakeFromNib {
    [super awakeFromNib];
    
    _logger = [[FCLogger alloc] init];
    _logger.textView = self.logView;
    
    commandHistory = [NSMutableArray arrayWithCapacity:100];
    commandHistoryPosition = -1;
    
    [FrapEndpointRedis sharedEndpoint].delegate = self;
}

-(void)didReceiveFrapMessage:(FrapMessage *)msg {
    [_logger addTextToLog:[[NSString alloc] initWithData:[msg encode] encoding:NSUTF8StringEncoding] withColor:[NSColor purpleColor]];
}

-(void)didSendFrapMessage:(FrapMessage *)msg {
    [_logger addTextToLog:[[NSString alloc] initWithData:[msg encode] encoding:NSUTF8StringEncoding] withColor:[NSColor colorWithRed:0.0 green:0.4 blue:0.0 alpha:1.0]];
}

-(void)sendCommand:(id)sender {
    NSString *commandString = self.commandPrompt.stringValue;
    if (commandString.length == 0) {
        return;
    }
    
    FrapMessage *msg = [FrapMessage decodeFrapMessage:commandString];
    
    if (msg) {
        [[FrapEndpoint sharedEndpoint] sendFrapMessage:msg];
    } else {
        DDLogError(@"Couldn't parse FRAP message: '%@'", commandString);
    }
    
    @synchronized(commandHistory) {
        if (commandHistory.count >= 100) {
            [commandHistory removeObjectsInRange:NSMakeRange(0, commandHistory.count - (100 - 1))];
        }
        
        [commandHistory addObject:commandString];
        savedCurrentCommand = nil;
    }
    
    self.commandPrompt.stringValue = @"";
}

-(BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(moveUp:)) {
        @synchronized(commandHistory) {
            if (commandHistoryPosition == 0) {
                return YES;
            } else if (commandHistoryPosition == -1) {
                if (commandHistory.count == 0) {
                    return YES;
                }
                
                savedCurrentCommand = self.commandPrompt.stringValue;
                commandHistoryPosition = (int)commandHistory.count - 1;
            } else if (commandHistory > 0) {
                commandHistory[--commandHistoryPosition] = self.commandPrompt.stringValue;
            }
        
            self.commandPrompt.stringValue = commandHistory[commandHistoryPosition];
            [self.commandPrompt.currentEditor moveToEndOfLine:0];
            return YES;
        }
    } else if (commandSelector == @selector(moveDown:)) {
        @synchronized(commandHistory) {
            if (commandHistoryPosition == -1) {
                return YES;
            }
            
            commandHistory[commandHistoryPosition] = self.commandPrompt.stringValue;
            if (commandHistoryPosition == ((int)commandHistory.count - 1)) {
                commandHistoryPosition = -1;
                self.commandPrompt.stringValue = savedCurrentCommand;
                savedCurrentCommand = nil;
            } else {
                self.commandPrompt.stringValue = commandHistory[++commandHistoryPosition];
            }
            [self.commandPrompt.currentEditor moveToEndOfLine:0];

            return YES;
        }
    }
    
    return NO;
}

@end

