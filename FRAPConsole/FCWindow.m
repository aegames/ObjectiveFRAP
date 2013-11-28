//
//  FRAPConsole.eero
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/13/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//
 
#import "FCWindow.h"
#import "FRAPEndpointXMPP.h"
#import "DDLog.h"

static int ddLogLevel = LOG_LEVEL_INFO;

@implementation FCWindow

@synthesize logger = _logger;

-(void)awakeFromNib {
    [super awakeFromNib];
    
    _logger = [[FCLogger alloc] init];
    _logger.textView = self.logView;
    
    [FrapEndpointXMPP sharedEndpoint].delegate = self;
}

-(void)didReceiveFrapMessage:(FrapMessage *)msg {
    [_logger addTextToLog:[[NSString alloc] initWithData:[msg encode] encoding:NSUTF8StringEncoding] withColor:[NSColor purpleColor]];
}

-(void)didSendFrapMessage:(FrapMessage *)msg {
    [_logger addTextToLog:[[NSString alloc] initWithData:[msg encode] encoding:NSUTF8StringEncoding] withColor:[NSColor greenColor]];
}

-(void)repl {
    char buf[4096];
    while (1) {
        printf("FRAPConsole > ");
        fgets(buf, sizeof(buf), stdin);
        
        if (feof(stdin))
            return;
        
        //NSString *cmd = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
    }
}

@end

