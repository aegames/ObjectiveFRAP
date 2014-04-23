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
    if (logMessage->logFlag & LOG_FLAG_ERROR) {
        color = [NSColor redColor];
    } else if (logMessage->logFlag & LOG_FLAG_WARN) {
        color = [NSColor orangeColor];
    } else if  (logMessage->logFlag & LOG_FLAG_INFO) {
        color = [NSColor colorWithRed:0.2 green:0.2 blue:0.5 alpha:1.0];
    } else if (logMessage->logFlag & LOG_FLAG_DEBUG) {
        color = [NSColor grayColor];
    } else {
        color = [NSColor darkGrayColor];
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
    
    BOOL scroll = (NSMaxY(self.textView.visibleRect) == NSMaxY(self.textView.bounds));
    
    [textView.textStorage beginEditing];
    [textView.textStorage appendAttributedString:attributedString];
    [textView.textStorage endEditing];
    
    NSRange range;
    range = NSMakeRange ([textView.string length], 0);
    
    if (scroll)
        [textView scrollRangeToVisible: range];
}

@end
