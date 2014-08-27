//
//  FLSortedArray.h
//  Fleep
//
//  Created by Erik Laansoo on 24.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL (^FilterFunc)(id element);
typedef struct _FLSortedArrayChange {
    BOOL allChanged;
    NSInteger oldPos;
    NSInteger newPos;
} FLSortedArrayChange;

@interface FLSortedArray : NSObject <NSFastEnumeration>
@property (nonatomic, readwrite, strong) FilterFunc filterFunc;
@property (nonatomic, readwrite, strong) NSComparator comparator;
@property (nonatomic, readwrite) NSArray* sourceArray;
@property (nonatomic, readwrite) NSDictionary* sourceDictionary;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) id lastObject;

- (FLSortedArrayChange)applyChanges:(NSArray*)changes;
- (id)objectAtIndexedSubscript:(NSInteger)index;
- (NSUInteger)indexOfObject:(id)object;
@end
