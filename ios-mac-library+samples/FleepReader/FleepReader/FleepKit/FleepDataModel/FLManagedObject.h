//
//  FLManagedObject.h
//  Fleep
//
//  Created by Erik Laansoo on 04.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "FLApiRequest.h"
#import "FLJsonParser.h"

@interface FLManagedObject : NSManagedObject
// JSON parsing helper
- (void)updateIntField:(NSString*)fieldName fromJson:(FLJsonParser*)json;
- (void)updateStringField:(NSString*)fieldName fromJson:(FLJsonParser*)json;
- (void)updateDateField:(NSString*)fieldName fromJson:(FLJsonParser*)json;

// KVO helper methods
- (void)addObserver:(NSObject*)observer forKeyPaths:(NSArray*)keyPaths;
- (void)removeObserver:(NSObject*)observer forKeyPaths:(NSArray*)keyPaths;

// Property change coalescing
- (void)willChangeProperty:(NSString*)property;
- (void)willChangeProperties:(NSArray*)properties;
- (void)notifyPropertyChanges;
+ (NSArray*)propertyNotificationOrder;

// Server sync
@property (nonatomic, retain) NSNumber * uncommitted_fields;
@property (nonatomic, readonly) BOOL needsSync;

- (void)setField:(NSInteger)field asDirty:(BOOL)dirty;
- (BOOL)isFieldDirty:(NSInteger)field;
- (FLApiRequest*)getSyncRequestForField:(NSInteger)field;
- (FLApiRequest*)getSyncRequest;
@end
