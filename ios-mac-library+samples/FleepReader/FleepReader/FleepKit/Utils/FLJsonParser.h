//
//  FLJsonParser.h
//  Fleep
//
//  Created by Erik Laansoo on 24.04.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^JsonParserKeyEnumerator)(NSString* key);

@interface FLJsonParser : NSObject

@property (nonatomic, readonly) NSError* error;
@property (nonatomic, readonly) NSDictionary* values;

+ (id)jsonParserForObject:(NSDictionary*) obj;
+ (id)jsonParserForString:(NSString*)str;
+ (id)jsonParserForData:(NSData*)data;
- (id)initWithObject:(NSDictionary*) obj;
- (id)initWithString:(NSString*)str;
- (id)initWithData:(NSData*)data;
- (BOOL)containsValue:(NSString*)key;
- (NSString*)extractString:(NSString*) key;
- (NSString*)extractString:(NSString*) key defaultValue:(NSString*) defaultValue;
- (NSRegularExpression*)extractRegex:(NSString*)key;
- (NSRegularExpression*)extractRegex:(NSString *)key defaultValue:(NSString*)defaultValue;
- (NSNumber*)extractInt:(NSString*) key;
- (NSNumber*)extractInt:(NSString*) key defaultValue:(NSNumber*) defaultValue;
- (NSNumber*)extractFloat:(NSString*) key;
- (NSNumber*)extractFloat:(NSString*) key defaultValue:(NSNumber*) defaultValue;
- (NSNumber*)extractBool:(NSString*) key;
- (NSNumber*)extractBool:(NSString*) key defaultValue:(BOOL) defaultValue;
- (NSNumber*)extractEnum:(NSString*) key valueMap:(NSDictionary*) valueMap;
- (NSNumber*)extractEnum:(NSString*) key valueMap:(NSDictionary*) valueMap defaultValue:(NSNumber*)defaultValue;
- (NSDate*)extractDate:(NSString*) key;
- (NSDate*)extractDate:(NSString*)key defaultValue:(NSDate*)defaultValue;
- (NSDate*)extractISOEncodedDate:(NSString*)key;
- (NSDate*)extractISOEncodedDate:(NSString *)key defaultValue:(NSDate*)defaultValue;
- (void)enumerateKeysUsingBlock:(JsonParserKeyEnumerator)block;
- (id)extractObject:(NSString*)key class:(Class)expectedClass;
- (id)extractObject:(NSString*)key class:(Class)expectedClass defaultValue:(id)defaultValue;

@end

@protocol JsonSerialization <NSObject>

- (NSError*) deserializeFromJson:(FLJsonParser*) json;
- (NSError*) updateFromJson:(FLJsonParser*) json;
@end
