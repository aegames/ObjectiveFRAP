//
//  FrapMessage.m
//  libfrap
//
//  Created by Nat Budin on 3/9/11.
//  Copyright 2011. All rights reserved.
//

#import "FrapMessages.h"

@implementation FrapMessage
@synthesize sender;

+(id)decodeFrapMessage:(NSString *)msgText {
	NSString *theSender = nil;
	NSString *msgType = nil;
	NSString *data = nil;
	
	NSUInteger msgPart = 0;
	NSUInteger partStart = 0;
	NSUInteger msgLength = [msgText length];
	NSUInteger i = 0;
	
	while (i < msgLength) {
		if (msgPart < 2) {
			unichar c = [msgText characterAtIndex:i];
			if (c == '|') {
				NSRange partRange = NSMakeRange(partStart, i - partStart);
				msgType = [msgText substringWithRange:partRange];
				
				partStart = i + 1;
				msgPart = 2;
			} else if (msgPart == 0 && c == ':') {
				NSRange senderRange = NSMakeRange(partStart, i - partStart);
				theSender = [msgText substringWithRange:senderRange];

				partStart = i + 1;
				msgPart = 1;
			}
		}
		i++;
	}
	
    if (partStart < [msgText length]) {
        data = [msgText substringFromIndex:partStart];
    } else {
        data = @"";
    }
	
    id msg = nil;
    @try {
        if ([msgType compare:@"tr"] == 0) {
            msg = [[FrapTriggerMessage alloc] initWithSender:theSender data:data];
        } else if ([msgType compare:@"set"] == 0) {
            msg = [[FrapSetSharedObjectMessage alloc] initWithSender:theSender data:data];
        } else if ([msgType compare:@"lt"] == 0) {
            msg = [[FrapLatencyTestMessage alloc] initWithSender:theSender];
        } else if ([msgType compare:@"id"] == 0) {
            msg = [[FrapIdentityMessage alloc] initWithSender:theSender];
        } else if ([msgType compare:@"idr"] == 0) {
            msg = [[FrapIdentityRequestMessage alloc] initWithSender:theSender];
        } else if ([msgType compare:@"up"] == 0) {
            msg = [[FrapStatusUpdateMessage alloc] initWithSender:theSender data:data];
        } else if ([msgType compare:@"sr"] == 0) {
            msg = [[FrapStatusRequestMessage alloc] initWithSender:theSender data:data];
        }
    }
    @catch (NSException *e) {
        NSLog(@"Exception while parsing FRAP %@ message data: %@", msgType, e);
        return nil;
    }
	
	return msg;
}

-(FrapMessage *)initWithSender:(NSString *)theSender {
	self.sender = theSender;
	
	return self;
}

-(NSData *)encode {
	return nil;
}

-(NSData *)encodeFromString:(NSString *)data withMsgTypeCode:(NSString *)typeCode {
	NSUInteger fullMsgLength = [typeCode length] + 1 + [data length];
	if (self.sender != nil) {
		fullMsgLength += [self.sender length] + 1;
	}

	NSMutableString *fullMsg = [NSMutableString stringWithCapacity:fullMsgLength];
	
	if (self.sender != nil) {
		[fullMsg setString:self.sender];
		[fullMsg appendString:@":"];
	} else {
		[fullMsg setString:@""];
	}
	
	[fullMsg appendString:typeCode];
	[fullMsg appendString:@"|"];
	[fullMsg appendString:data];
	
	NSData *encoded = [fullMsg dataUsingEncoding:NSUTF8StringEncoding];
	return encoded;
}

-(NSData *)encodeFromData:(NSData *)data withMsgTypeCode:(NSString *)typeCode {
    
	NSMutableData *fullMsg = [[self encodeFromString:@"" withMsgTypeCode:typeCode] mutableCopy];
	[fullMsg appendData:data];
	
	return fullMsg;
}

-(NSString *)descriptionWithText:(NSString *)text {
    return [NSString stringWithFormat:@"%@ from %@", text, self.sender];
}

@end

@implementation FrapKeyValueMessage
@synthesize key, value;

-(FrapKeyValueMessage *)initWithKey:(NSString *)theKey value:(NSObject *)theValue {
    self.key = theKey;
    self.value = theValue;
    
    return self;
}

-(FrapKeyValueMessage *)initWithSender:(NSString *)theSender data:(NSString *)data {
	self = [super initWithSender:theSender];
    
	NSRange separatorRange = [data rangeOfString:@"|"];
	
	self.key = [data substringToIndex:separatorRange.location];
	NSUInteger argsStart = separatorRange.location + separatorRange.length;
	
    NSError *decodingError;
    NSData *valueData = [[data substringFromIndex:argsStart] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *jsonValue = [NSJSONSerialization JSONObjectWithData:valueData options:NSJSONReadingMutableContainers error:&decodingError];    
    [self setValuesForKeysWithDictionary:jsonValue];
	
	return self;
}

-(NSData *)encode {
    NSError *encodingError;
    NSData *encodedValue = [NSJSONSerialization dataWithJSONObject:[self dictionaryWithValuesForKeys:[self.class propertiesForJSON]] options:0 error:&encodingError];
	
	NSUInteger dataLength = [self.key length] + 1 + [encodedValue length];
	NSMutableString *data = [NSMutableString stringWithCapacity:dataLength];
	[data setString:self.key];
	[data appendString:@"|"];
	
	NSMutableData *encodedData = [[super encodeFromString:data withMsgTypeCode:[self.class messageTypeCode]] mutableCopy];
    [encodedData appendData:encodedValue];
    return encodedData;
}

+(NSArray *)propertiesForJSON {
    return @[ @"value" ];
}

// this should be overridden by subclasses
+(NSString *)messageTypeCode {
    return nil;
}
@end

@implementation FrapTriggerMessage
-(id)initWithEventId:(NSString *)eventId {
    return [self initWithEventId:eventId args:[[NSArray alloc] init]];
}

-(id)initWithEventId:(NSString *)eventId args:(NSArray *)args {
    return [self initWithKey:eventId value:args];
}

-(NSArray *)args {
	return (NSArray *)self.value;
}

-(NSString *)eventId {
	return self.key;
}

+(NSString *)messageTypeCode {
    return @"tr";
}

-(NSString *)description {
    return [super descriptionWithText:[NSString stringWithFormat:@"Trigger event %@ %@", self.eventId, self.args]];
}

@end

@implementation FrapSetSharedObjectMessage
@synthesize previousValue;

-(id)initWithKey:(NSString *)key value:(NSObject *)value previousValue:(NSObject *)prevValue {
    self = [super initWithKey:key value:value];
    self.previousValue = prevValue;
    return self;
}

+(NSString *)messageTypeCode {
    return @"set";
}

-(NSString *)description {
    return [super descriptionWithText:[NSString stringWithFormat:@"Set shared object %@ to %@", self.key, self.value]];
}

+(NSArray *)propertiesForJSON {
    return @[@"value", @"previousValue"];
}
@end

@implementation FrapLatencyTestMessage
-(id)initWithSender:(NSString *)theSender {
	self = [super initWithSender:theSender];
	started = [NSDate date];
	return self;
}

-(NSDate *)started {
	return started;
}

-(NSData *)encode {
	return [super encodeFromString:@"" withMsgTypeCode:@"lt"];
}

-(NSString *)description {
	return [super descriptionWithText:@"Latency test"];
}

@end

@implementation FrapIdentityMessage
-(id)initWithSender:(NSString *)theSender {
	return [super initWithSender:theSender];
}

-(NSData *)encode {
	return [super encodeFromString:@"" withMsgTypeCode:@"id"];
}

-(NSString *)description {
	return [super descriptionWithText:@"Identity"];
}
@end

@implementation FrapIdentityRequestMessage
-(id)initWithSender:(NSString *)theSender {
	return [super initWithSender:theSender];
}

-(NSData *)encode {
	return [super encodeFromString:@"" withMsgTypeCode:@"idr"];
}

-(NSString *)description {
	return [super descriptionWithText:@"Identity request"];
}
@end


@implementation FrapStatusUpdateMessage
@synthesize objects;

-(id)initWithSender:(NSString *)theSender data:(NSString *)data {
	self = [super initWithSender:theSender];
	
    NSError *decodingError;
    objects = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&decodingError];
	
	return self;
}

-(NSData *)encode {
    NSError *encodingError;
    NSData *data = [NSJSONSerialization dataWithJSONObject:objects options:0 error:&encodingError];
    
	return [super encodeFromData:data withMsgTypeCode:@"up"];
}

-(NSString *)description {
	return [super descriptionWithText:@"Status update"];
}

@end

@implementation FrapStatusRequestMessage
@synthesize objectIds;

-(id)initWithSender:(NSString *)theSender data:(NSString *)data {
	self = [super initWithSender:theSender];
	objectIds = [[data componentsSeparatedByString:@"|"] mutableCopy];
	return self;
}

-(NSData *)encode {
	NSString *data = [objectIds componentsJoinedByString:@"|"];
	return [super encodeFromString:data withMsgTypeCode:@"sr"];
}

-(NSString *)description {
	return [super descriptionWithText:@"Status request"];
}

@end