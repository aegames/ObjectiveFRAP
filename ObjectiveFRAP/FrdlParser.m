//
//  FrapParser.m
//  foh-iphone
//
//  Created by Nat Budin on 1/12/13.
//
//

#import "FrdlParser.h"

FrdlParser *sharedParser = nil;

@interface FrdlParser ()
-(void)addSharedObjectToCurrentRole:(NSString *)key;
@end

@implementation FrdlParser

+(FrdlParser *)sharedParser {
    @synchronized (sharedParser) {
        if (sharedParser == nil) {
            sharedParser = [[FrdlParser alloc] init];
        }
    }
    
    return sharedParser;
}

+(void)parseGameFrdlAndSetFrapEndpointDefaults {
    FrdlParser *parser = [FrdlParser sharedParser];
    [parser parseGameFrdl];
    [parser setDefaultsForFrapEndpoint:[FrapEndpoint sharedEndpoint] sendMessages:NO];
}

-(FrdlParser *)init {
    sharedObjectDefaultValues = [[NSMutableDictionary alloc] init];
    sharedObjectTypes = [[NSMutableDictionary alloc] init];
    enumOptions = [[NSMutableDictionary alloc] init];
    eventArgs = [[NSMutableDictionary alloc] init];
    roleSharedObjects = [[NSMutableDictionary alloc] init];
    return self;
}

-(void)parseUrl:(NSURL *)url {
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:url];
    xmlParser.delegate = self;
    [xmlParser parse];
}

-(void)parseGameFrdl {
    [self parseUrl:[[NSBundle mainBundle] URLForResource:@"game" withExtension:@"frdl"]];
}

-(void)addSharedObjectToCurrentRole:(NSString *)key {
    if (currentRole != nil) {
        NSMutableArray *sharedObjects = [roleSharedObjects valueForKey:currentRole];
        [sharedObjects addObject:key];
    }
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    
    if ([elementName isEqualToString:@"number"]) {
        NSNumber *value = [NSNumber numberWithFloat:[(NSString *)[attributeDict valueForKey:@"value"] floatValue]];
        [sharedObjectDefaultValues setValue:value forKey:[attributeDict valueForKey:@"id"]];
        [sharedObjectTypes setValue:[NSNumber numberWithInt:FrapNumber] forKey:[attributeDict valueForKey:@"id"]];
        [self addSharedObjectToCurrentRole:[attributeDict valueForKey:@"id"]];
    } else if ([elementName isEqualToString:@"bool"]) {
        [sharedObjectDefaultValues setValue:[attributeDict valueForKey:@"value"] forKey:[attributeDict valueForKey:@"id"]];
        [sharedObjectTypes setValue:[NSNumber numberWithInt:FrapBoolean] forKey:[attributeDict valueForKey:@"id"]];
        [self addSharedObjectToCurrentRole:[attributeDict valueForKey:@"id"]];
    } else if ([elementName isEqualToString:@"enum"]) {
        currentEnumKey = [attributeDict valueForKey:@"id"];
        [enumOptions setValue:[[NSMutableArray alloc] init] forKey:currentEnumKey];
        [sharedObjectDefaultValues setValue:[attributeDict valueForKey:@"value"] forKey:[attributeDict valueForKey:@"id"]];
        [sharedObjectTypes setValue:[NSNumber numberWithInt:FrapEnum] forKey:[attributeDict valueForKey:@"id"]];
        [self addSharedObjectToCurrentRole:[attributeDict valueForKey:@"id"]];
    } else if ([elementName isEqualToString:@"code"] && currentEnumKey != nil) {
        NSMutableArray *options = (NSMutableArray *)[enumOptions valueForKey:currentEnumKey];
        [options addObject:[attributeDict valueForKey:@"name"]];
    } else if ([elementName isEqualToString:@"event"]) {
        currentEventKey = [attributeDict valueForKey:@"id"];
        [eventArgs setValue:[[NSMutableArray alloc] init] forKey:currentEventKey];
    } else if ([elementName isEqualToString:@"arg"] && currentEventKey != nil) {
        NSMutableArray *args = (NSMutableArray *)[eventArgs valueForKey:currentEventKey];
        [args addObject:[attributeDict valueForKey:@"name"]];
    } else if ([elementName isEqualToString:@"role"]) {
        currentRole = [attributeDict valueForKey:@"name"];
        [roleSharedObjects setValue:[[NSMutableArray alloc] init] forKey:currentRole];
        
        currentEnumKey = [NSString stringWithFormat:@"state_%@", currentRole];
        [enumOptions setValue:[[NSMutableArray alloc] init] forKey:currentEnumKey];
        [sharedObjectTypes setValue:[NSNumber numberWithInt:FrapEnum] forKey:currentEnumKey];
    } else if (([elementName isEqualToString:@"state"] || [elementName isEqualToString:@"use-state"]) && currentEnumKey != nil) {
        NSMutableArray *options = (NSMutableArray *)[enumOptions valueForKey:currentEnumKey];
        [options addObject:[attributeDict valueForKey:@"name"]];
        if ([[attributeDict valueForKey:@"start"] isEqualToString:@"true"]) {
            [sharedObjectDefaultValues setValue:[attributeDict valueForKey:@"name"] forKey:currentEnumKey];
        }
    }
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"enum"] || [elementName isEqualToString:@"role"]) {
        currentEnumKey = nil;
    } else if ([elementName isEqualToString:@"event"]) {
        currentEventKey = nil;
    }
}

-(NSDictionary *)sharedObjectDefaultValues {
    return [sharedObjectDefaultValues copy];
}

-(NSArray *)optionsForEnum:(NSString *)key {
    return [[enumOptions valueForKey:key] sortedArrayUsingSelector:@selector(compare:)];
}

-(void)setDefaultsForFrapEndpoint:(FrapEndpoint *)endpoint sendMessages:(BOOL)sendMessages {
    for (NSString *key in [sharedObjectDefaultValues keyEnumerator]) {
        [endpoint setSharedObjectAtKey:key toValue:[sharedObjectDefaultValues valueForKey:key] sendMessage:sendMessages];
    }
}

-(NSDictionary *)eventArgs {
    return [eventArgs copy];
}

-(enum FrapSharedObjectType) sharedObjectTypeForKey:(NSString *)key {
    return [(NSNumber *)[sharedObjectTypes valueForKey:key] intValue];
}

-(NSArray *)sharedObjectsOwnedByRole:(NSString *)role {
    return [roleSharedObjects valueForKey:role];
}

@end
