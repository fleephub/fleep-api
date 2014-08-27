//
//  FLJsonParser.m
//  Fleep
//
//  Created by Erik Laansoo on 24.04.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import "FLJsonParser.h"
#import "FLUtils.h"

@implementation FLJsonParser
{
    NSDictionary* _values;
    NSError* _error;
}

@synthesize error = _error;
@synthesize values = _values;

+ (id)jsonParserForData:(NSData *)data
{
    return [[self alloc] initWithData:data];
}

+ (id)jsonParserForString:(NSString*)str
{
    return [[self alloc]initWithString:str];
}

- (id)initWithData:(NSData *)data
{
    NSError* err;
    NSDictionary* obj = [NSJSONSerialization JSONObjectWithData: data
         options:0 error:&err];
    _error = err;
    return [self initWithObject:obj];
}

- (id)initWithString:(NSString*)str
{
    return [self initWithData:[str dataUsingEncoding:NSUTF8StringEncoding]];
}

+ (id)jsonParserForObject:(NSDictionary*) obj
{
    return [[FLJsonParser alloc] initWithObject:obj];
}

- (id)initWithObject:(NSDictionary*) obj
{
    _values = obj;
    return self;
}

- (void)failWithError:(NSInteger)errorCode userInfo:(NSDictionary*)userInfo
{
    if (_error != nil) {
        return;
    }
    
    NSMutableDictionary* ui = [[NSMutableDictionary alloc] init];
    if (userInfo != nil) {
        [ui addEntriesFromDictionary:userInfo];
    }
    ui[@"data"] = _values;
    _error = [FLError errorWithCode:errorCode andUserInfo:ui];
}

- (id)validateValue:(id)value key:(NSString*)key requirePresent:(BOOL)required requireClass:(Class)class
{
    if ((value == nil) || [value isKindOfClass:[NSNull class]]) {
        if (required) {
            [self failWithError:FLEEP_ERROR_MISSING_VALUE userInfo:
                  @{ @"key" : key }];
        }
        return nil;
    }
    
    if ((class != nil) && ![value isKindOfClass:class]) {
        [self failWithError:FLEEP_ERROR_INCORRECT_TYPE userInfo: @{@"key": key, @"class":[[value class]description]}];
        return nil;
    }
    
    return value;
}

- (id)extractValue:(NSString*) key fromObject:(NSDictionary*)obj requirePresent:(BOOL)required
    requireClass:(Class)class
{
    return [self validateValue:[obj valueForKey:key] key:key requirePresent:required requireClass:class];
}

- (id)extractValue:(NSString*) key requirePresent:(BOOL)required requireClass:(Class)class
{
    NSDictionary* current = _values;
    NSArray* pathComponents = [key componentsSeparatedByString:@"/"];
    
    for (NSInteger i = 0; i < pathComponents.count; i++) {
        NSString* pc = [pathComponents objectAtIndex:i];
        NSInteger bracketPos = [pc rangeOfString:@"["].location;
        if (bracketPos == NSNotFound) {
            if (i == pathComponents.count - 1) {
                return [self extractValue:pc fromObject:current requirePresent:required requireClass:class];
            } else {
                current = [self extractValue:pc fromObject:current requirePresent:required requireClass:[NSDictionary class]];
            }
        } else {
            if (![[pc substringFromIndex:pc.length - 1] isEqualToString:@"]"]) {
                FLLogError(@"Invalid JSON expression: %@", key);
                assert(false);
            }
            NSString* childName = [pc substringToIndex:bracketPos];
            NSString* childIndex = [pc substringWithRange:NSMakeRange(bracketPos + 1, pc.length - bracketPos - 2)];
            NSInteger idx = [childIndex integerValue];

            NSArray* childElement = [self extractValue:childName fromObject:current requirePresent:required requireClass:[NSArray class]];
            if (childElement != nil) {
                if (idx >= childElement.count) {
                    if (required) {
                        [self failWithError:FLEEP_ERROR_MISSING_VALUE userInfo:@{ @"key" : key}];
                    }
                    return nil;
                }
                id next = [childElement objectAtIndex:idx];

                if (i == pathComponents.count - 1) {
                    return [self validateValue:next key:key requirePresent:required requireClass:class];
                }

                current = [self validateValue:next key:key requirePresent:YES requireClass:[NSDictionary class]];
            } else {
                current = nil;
            }
        }
        if (current == nil) {
            return nil;
        }
    }

    return current;
}

- (NSString*)extractString:(NSString*) key
{
    return [self extractValue:key requirePresent:YES requireClass:NSString.class];
}

- (BOOL)containsValue:(NSString *)key
{
    return [self extractValue:key requirePresent:NO requireClass:nil] != nil;
}

- (NSString*)extractString:(NSString*) key defaultValue:(NSString*) defaultValue
{
    id res = [self extractValue:key requirePresent:NO requireClass:NSString.class];
    return (res == nil) ? defaultValue : res;
}

- (NSNumber*)extractInt:(NSString*) key
{
    return [self extractValue:key requirePresent:YES requireClass:NSNumber.class];
}
          
- (NSNumber*)extractInt:(NSString*) key defaultValue:(NSNumber*) defaultValue
{
    id res = [self extractValue:key requirePresent:NO requireClass:NSNumber.class];
    return (res == nil) ? defaultValue : res;
}

- (NSNumber*)extractFloat:(NSString*) key
{
    id res = [self extractValue:key requirePresent:YES requireClass:NSNumber.class];

    return res;
}
          
- (NSNumber*)extractFloat:(NSString*) key defaultValue:(NSNumber*) defaultValue
{
    id res = [self extractValue:key requirePresent:NO requireClass:NSNumber.class];
    return (res == nil) ? defaultValue : res;
}

- (NSNumber*)extractEnum:(NSString*) key valueMap:(NSDictionary*) valueMap
{
    NSString* res = [self extractString:key];
    if (res == nil) {
        return 0;
    }
    id value = [valueMap valueForKey:res];
    if (value == nil) {
        [self failWithError:FLEEP_ERROR_INCORRECT_ENUM
            userInfo:@ { @"key" : key, @"value" : res}];
        return nil;
    }
    assert([value isKindOfClass:[NSNumber class]]);
    return value;
}
          
- (NSNumber*)extractEnum:(NSString*) key valueMap:(NSDictionary*) valueMap defaultValue:(NSNumber*)defaultValue
{
    NSString* res = [self extractString:key defaultValue:nil];
    if (res == nil) {
        return defaultValue;
    }
    id value = [valueMap valueForKey:res];
    if (value == nil) {
        FLLogWarning(@"JsonParser::ExtractEnum: Unknown value '%@' for key '%@'", res, key);
        return defaultValue;
    }
    assert([value isKindOfClass:NSNumber.class]);
    return value;
}

- (NSNumber*)extractBool:(NSString*) key
{
    return [self extractInt:key];
}

- (NSNumber*)extractBool:(NSString*) key defaultValue:(BOOL) defaultValue;
{
    return [self extractInt:key defaultValue:[NSNumber numberWithBool:defaultValue]];
}

- (NSDate*)extractDate:(NSString*) key
{
    NSNumber* v = [self extractValue:key requirePresent:YES requireClass:NSNumber.class];
    if (v == nil) {
        return nil;
    }

    return [NSDate dateWithTimeIntervalSince1970:v.integerValue];
}

- (NSDate*)extractDate:(NSString*) key defaultValue:(NSDate *)defaultValue
{
    NSNumber* v = [self extractValue:key requirePresent:NO requireClass:NSNumber.class];
    if (v == nil) {
        return defaultValue;
    }

    return [NSDate dateWithTimeIntervalSince1970:v.integerValue];
}

- (NSDate*)dateFromISOEncodedDate:(NSString*)encodedDate
{
    static NSDateFormatter* dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSSSZ"];
    }

    NSDate* d;
    NSRange r = NSMakeRange(0, encodedDate.length);
    NSError* err;

    if (![dateFormatter getObjectValue:&d forString:encodedDate range:&r error:&err])
    {
        _error = err;
        return nil;
    }

    return d;
}

- (NSDate*)extractISOEncodedDate:(NSString*)key defaultValue:(NSDate *)defaultValue
{
    NSString* v = [self extractValue:key requirePresent:NO requireClass:NSString.class];
    if (v == nil) {
        return defaultValue;
    }

    return [self dateFromISOEncodedDate:v];
}

- (NSDate*)extractISOEncodedDate:(NSString *)key
{
    NSString* v = [self extractValue:key requirePresent:YES requireClass:NSString.class];
    if (v == nil) {
        return nil;
    }

    return [self dateFromISOEncodedDate:v];
}

- (id)extractObject:(NSString*)key class:(Class)expectedClass
{
    return [self extractValue:key requirePresent:YES requireClass:expectedClass];
}

- (id)extractObject:(NSString*)key class:(Class)expectedClass defaultValue:(id)defaultValue
{
    id res = [self extractValue:key requirePresent:NO requireClass:expectedClass];
    return (res == nil) ? defaultValue : res;
}

- (NSString*)description
{
    return _values.description;
}

- (NSRegularExpression*)extractRegex:(NSString*)key
{
    NSString* pattern = [self extractString:key];
    if (pattern == nil) {
        return nil;
    }
    NSError* error = nil;
    NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionAnchorsMatchLines error:&error];
    if (error != nil) {
        _error = error;
        return nil;
    }
    return re;
}

- (NSRegularExpression*)extractRegex:(NSString *)key defaultValue:(NSString*)defaultValue
{
    NSString* pattern = [self extractString:key defaultValue:defaultValue];

    NSError* error = nil;
    NSRegularExpression* re = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:&error];
    if (error != nil) {
        _error =error;
        return nil;
    }
    return re;
}

- (void)enumerateKeysUsingBlock:(JsonParserKeyEnumerator)block
{
    [_values enumerateKeysAndObjectsUsingBlock:^(NSString* key, id obj, BOOL *stop) {
        block(key);
    }];
}

@end
