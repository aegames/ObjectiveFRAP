//
//  FrapSharedObject.h
//  FRAP
//
//  Created by Nat Budin on 12/18/12.
//  Copyright (c) 2012 Alleged Entertainment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FrapEndpoint.h"

@interface FrapSharedObject : NSObject {
    NSLock *lock;
}

@property NSString *key;
@property (nonatomic) NSObject *value;
@property FrapEndpoint *endpoint;

-(id)initWithEndpoint:(FrapEndpoint *)endpoint key:(NSString *)key;

@end
