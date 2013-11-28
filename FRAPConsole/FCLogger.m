//
//  FCLogger.m
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/28/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "FCLogger.h"

@implementation FCLogger

@synthesize textView;

-(id)init {
    self = [super init];
    font = [NSFont userFixedPitchFontOfSize:12.0];
    
    return self;
}

-(void)logMessage:(DDLogMessage *)logMessage {
    NSColor *color;
    switch (logMessage->logLevel) {
        case LOG_LEVEL_DEBUG:
            color = [NSColor grayColor];
            break;
        case LOG_LEVEL_INFO:
            color = [NSColor colorWithRed:0.2 green:0.2 blue:0.5 alpha:1.0];
            break;
        case LOG_LEVEL_WARN:
            color = [NSColor orangeColor];
            break;
        case LOG_LEVEL_ERROR:
            color = [NSColor redColor];
            break;
        default:
            color = [NSColor darkGrayColor];
            break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self addTextToLog:logMessage->logMsg withColor:color];
    });
}

-(void)addTextToLog:(NSString *)text withColor:(NSColor *)color {
    NSAttributedString *attributedString = [[NSAttributedString alloc]
                                            initWithString:[NSString stringWithFormat:@"%@\n", text]
                                                attributes:@{
                                                             NSFontAttributeName : font,
                                                             NSForegroundColorAttributeName : color}];
    
    [textView.textStorage beginEditing];
    [textView.textStorage appendAttributedString:attributedString];
    [textView.textStorage endEditing];
    
    NSRange range;
    range = NSMakeRange ([textView.string length], 0);
    
    [textView scrollRangeToVisible: range];
}

@end
