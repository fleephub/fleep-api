//
//  FLManagedObject.m
//  Fleep
//
//  Created by Erik Laansoo on 04.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLManagedObject.h"

@implementation FLManagedObject
{
    NSMutableSet* _changedProperties;
}

@dynamic uncommitted_fields;

+ (NSArray*)propertyNotificationOrder
{
    return nil;
}

- (void)updateIntField:(NSString*)fieldName fromJson:(FLJsonParser*)json
{
    NSNumber* value = [self valueForKey:fieldName];
    NSNumber* newValue = [json extractInt:fieldName defaultValue:value];

    if ((newValue == nil) || [newValue isEqualToNumber:value]) {
        return;
    }

    [self willChangeProperty:fieldName];
    [self setValue:newValue forKey:fieldName];
}

- (void)updateStringField:(NSString*)fieldName fromJson:(FLJsonParser*)json
{
    NSString* value = [self valueForKey:fieldName];
    NSString* newValue = [json extractString:fieldName defaultValue:value];

    if ((newValue == nil) || [newValue isEqualToString:value]) {
        return;
    }

    [self willChangeProperty:fieldName];
    [self setValue:newValue forKey:fieldName];
}

- (void)updateDateField:(NSString*)fieldName fromJson:(FLJsonParser*)json
{
    NSDate* value = [self valueForKey:fieldName];
    NSDate* newValue = [json extractDate:fieldName defaultValue:value];

    if ((newValue == nil) || [newValue isEqualToDate:value]) {
        return;
    }

    [self willChangeProperty:fieldName];
    [self setValue:newValue forKey:fieldName];
}


- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray *)keyPaths
{
    for (NSString* kp in keyPaths) {
        [self addObserver:observer forKeyPath:kp options:0 context:nil];
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSArray *)keyPaths
{
    for (NSString* kp in keyPaths) {
        [self removeObserver:observer forKeyPath:kp];
    }
}

- (void)willChangeProperties:(NSArray*)properties
{
    if (_changedProperties == nil) {
        _changedProperties = [[NSMutableSet alloc] init];
    }
    for (NSString* prop in properties) {
        if (![_changedProperties containsObject:prop]) {
            [self willChangeValueForKey:prop];
            [_changedProperties addObject:prop];
        }
    }
}

- (void)willChangeProperty:(NSString*)property
{
    [self willChangeProperties:@[property]];
}

- (void)notifyPropertyChanges
{
    if (_changedProperties == nil) {
        return;
    }

    NSArray* order = [self.class propertyNotificationOrder];
    if (order != nil) {
        for (NSString* prop in order) {
            if ([_changedProperties containsObject:prop]) {
                [self didChangeValueForKey:prop];
                [_changedProperties removeObject:prop];
            }
        }
    }

    for (NSString* prop in _changedProperties.allObjects) {
        [self didChangeValueForKey:prop];
    }

    _changedProperties = nil;
}

- (BOOL)needsSync
{
    return (self.uncommitted_fields != nil) && (self.uncommitted_fields.integerValue > 0);
}

- (BOOL)isFieldDirty:(NSInteger)field
{
    if (self.uncommitted_fields == nil) {
        return NO;
    } else {
        return (self.uncommitted_fields.integerValue & (1 << field)) != 0;
    }
}

- (void)setField:(NSInteger)field asDirty:(BOOL)dirty
{
    NSUInteger currentValue = self.uncommitted_fields != nil ? self.uncommitted_fields.unsignedIntegerValue : 0;
    NSUInteger newValue = currentValue;
    if (dirty) {
        newValue |= (1 << field);
    } else {
        NSUInteger mask = 0xffffffff ^ (1 << field);
        newValue &= mask;
    }

    if (currentValue == newValue) {
        return;
    }

    if (newValue == 0) {
        self.uncommitted_fields = nil;
    } else {
        self.uncommitted_fields = [NSNumber numberWithInteger:newValue];
    }
}

- (FLApiRequest*)getSyncRequestForField:(NSInteger)field
{
    return nil;
}

- (FLApiRequest*)getSyncRequest
{
    if ((self.uncommitted_fields == nil) || (self.uncommitted_fields.integerValue == 0)) {
        return nil;
    }

    FLApiRequest* request = nil;
    NSInteger field;

    for (NSInteger i = 0; i < 32; i++) {
        if ([self isFieldDirty:i]) {
            request = [self getSyncRequestForField:i];
            if (request == nil) {
                [self setField:i asDirty:NO];
            } else {
                field = i;
                break;
            }
        }
    }

    if (request == nil) {
        return nil;
    }

    if (request.errorHandler == nil) {
        request.errorHandler = ^(NSError* error) {
            if ((error.code >= 400) && (error.code <= 499)) {
                [self setField:field asDirty:NO];
            }
        };
    };

    if (request.handler == nil) {
        request.handler = ^NSError*(FLJsonParser* json) {
            [self setField:field asDirty:NO];
            return nil;
        };
    }

    return request;
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return NO;
}

@end
