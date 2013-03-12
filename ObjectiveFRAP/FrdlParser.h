//
//  FrapParser.h
//  foh-iphone
//
//  Created by Nat Budin on 1/12/13.
//
//

#import <Foundation/Foundation.h>
#import "FrapEndpoint.h"

enum FrapSharedObjectType {
    FrapNumber = 1,
    FrapBoolean = 2,
    FrapEnum = 3
};

@interface FrdlParser : NSObject<NSXMLParserDelegate> {
    NSMutableDictionary *sharedObjectDefaultValues;
    NSMutableDictionary *sharedObjectTypes;
    NSMutableDictionary *enumOptions;
    NSMutableDictionary *roleSharedObjects;
    NSString *currentEnumKey;
    
    NSMutableDictionary *eventArgs;
    NSString *currentEventKey;
    NSString *currentRole;
}

+(FrdlParser *)sharedParser;
+(void)parseGameFrdlAndSetFrapEndpointDefaults;

-(void)parseUrl:(NSURL *)url;
-(void)parseGameFrdl;
-(NSDictionary *)sharedObjectDefaultValues;
-(NSArray *)optionsForEnum:(NSString *)key;
-(void)setDefaultsForFrapEndpoint:(FrapEndpoint *)endpoint sendMessages:(BOOL)sendMessages;
-(NSDictionary *)eventArgs;
-(enum FrapSharedObjectType)sharedObjectTypeForKey:(NSString *)key;
-(NSArray *)sharedObjectsOwnedByRole:(NSString *)role;

@end
