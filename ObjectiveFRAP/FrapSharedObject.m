//
//  FrapSharedObject.m
//  FRAP
//
//  Created by Nat Budin on 12/18/12.
//  Copyright (c) 2012 Alleged Entertainment. All rights reserved.
//

#import "FrapSharedObject.h"

@implementation FrapSharedObject

-(id)init {
    lock = [[NSLock alloc] init];
    return self;
}

-(id)initWithEndpoint:(FrapEndpoint *)endpoint key:(NSString *)key {
    self = [self init];
    self.endpoint = endpoint;
    self.key = key;
    
    return self;
}

-(void)setValue:(NSObject *)value {
    [lock lock];
    _value = value;
    [lock unlock];
}

@end
