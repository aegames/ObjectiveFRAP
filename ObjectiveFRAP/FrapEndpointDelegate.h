//
//  FRAPEndpointDelegate.h
//  foh-iphone
//
//  Created by Nat Budin on 5/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FrapMessages.h"

@protocol FrapEndpointDelegate <NSObject>

@optional
-(void)didSendFrapMessage:(FrapMessage *)msg;
-(void)didReceiveFrapMessage:(FrapMessage *)msg;
@end
