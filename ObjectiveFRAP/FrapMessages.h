//
//  FrapMessage.h
//  libfrap
//
//  Created by Nat Budin on 3/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FrapMessage : NSObject
@property NSString *sender;

+(id)decodeFrapMessage:(NSString *)msgText;
-(FrapMessage *)initWithSender:(NSString *) theSender;
-(NSString *)sender;
-(NSData *)encode;
-(NSData *)encodeFromString:(NSString *)data withMsgTypeCode:(NSString *)typeCode;
-(NSData *)encodeFromData:(NSData *)data withMsgTypeCode:(NSString *)typeCode;
-(NSString *)descriptionWithText:(NSString *)text;
@end

@interface FrapKeyValueMessage : FrapMessage
@property NSString *key;
@property NSObject *value;

-(id)initWithSender:(NSString *)theSender data:(NSString *)data;
-(id)initWithKey:(NSString *)key value:(NSObject *)value;
-(NSData *)encode;
+(NSArray *)propertiesForJSON;
+(NSString *)messageTypeCode;
@end

@interface FrapTriggerMessage : FrapKeyValueMessage
-(id)initWithEventId:(NSString *)eventId;
-(id)initWithEventId:(NSString *)eventId args:(NSArray *)args;
-(NSString *)eventId;
-(NSMutableArray *)args;
-(NSString *)description;
@end

@interface FrapSetSharedObjectMessage : FrapKeyValueMessage
@property NSObject *previousValue;
-(id)initWithKey:(NSString *)key value:(NSObject *)value previousValue:(NSObject *)previousValue;
-(NSString *)description;
@end

@interface FrapLatencyTestMessage : FrapMessage {
	NSDate *started;
}
-(id)initWithSender:(NSString *)theSender;
-(NSDate *)started;
-(NSData *)encode;
-(NSString *)description;
@end

@interface FrapIdentityMessage : FrapMessage {
}
-(id)initWithSender:(NSString *)theSender;
-(NSData *)encode;
-(NSString *)description;
@end

@interface FrapIdentityRequestMessage : FrapMessage {
}
-(id)initWithSender:(NSString *)theSender;
-(NSData *)encode;
-(NSString *)description;
@end

@interface FrapStatusRequestMessage : FrapMessage
@property NSMutableArray *objectIds;
-(id)initWithSender:(NSString *)theSender data:(NSString *)data;
-(NSArray *)objectIds;
-(NSData *)encode;
-(NSString *)description;
@end

@interface FrapStatusUpdateMessage : FrapMessage
@property NSMutableDictionary *objects;
-(id)initWithSender:(NSString *)theSender data:(NSString *)data;
-(NSData *)encode;
-(NSString *)description;
@end