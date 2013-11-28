//
//  FCLogger.h
//  ObjectiveFRAP
//
//  Created by Nat Budin on 11/28/13.
//  Copyright (c) 2013 Alleged Entertainment. All rights reserved.
//

#import "DDLog.h"

@interface FCLogger : DDAbstractLogger {
    NSFont *font;
}

@property NSTextView *textView;

-(void)addTextToLog:(NSString *)text withColor:(NSColor *)color;

@end
