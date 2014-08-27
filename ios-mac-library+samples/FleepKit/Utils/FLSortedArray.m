//
//  FLSortedArray.m
//  Fleep
//
//  Created by Erik Laansoo on 24.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLSortedArray.h"

@implementation FLSortedArray
{
    NSMutableArray* _items;
    FilterFunc _filterFunc;
    NSComparator _comparator;
    NSArray* _sourceArray;
    NSDictionary* _sourceDictionary;
}

@synthesize filterFunc = _filterFunc;
@synthesize comparator = _comparator;

- (NSArray*)sourceArray
{
    return _sourceArray;
}

- (NSDictionary*)sourceDictionary
{
    return _sourceDictionary;
}

- (void)populateFromArray:(NSArray*)source
{
    if (_filterFunc == nil) {
        _items = [source mutableCopy];
        [_items sortUsingComparator:_comparator];
    } else {
        _items = [[NSMutableArray alloc] initWithCapacity:source.count];
        for (id item in source) {
            if (_filterFunc(item)) {
                NSInteger newIndex = [_items indexOfObject:item inSortedRange:NSMakeRange(0, _items.count)
                    options:NSBinarySearchingInsertionIndex
                    usingComparator:_comparator];
                [_items insertObject:item atIndex:newIndex];
            }
        }
    }
}

- (void)setSourceArray:(NSArray *)sourceArray
{
    assert(_comparator != nil);
    assert(_sourceDictionary == nil);
    if (_sourceArray == sourceArray) {
        return;
    }
    _sourceArray = sourceArray;
    if (_sourceArray == nil) {
        _items = nil;
    } else {
        [self populateFromArray:_sourceArray];
    }
}

- (void)setSourceDictionary:(NSDictionary *)sourceDictionary
{
    assert(_comparator != nil);
    assert(_sourceArray == nil);
    if (_sourceDictionary == sourceDictionary) {
        return;
    }
    _sourceDictionary = sourceDictionary;
    if (_sourceDictionary == nil) {
        _items = nil;
    } else {
        [self populateFromArray:_sourceDictionary.allValues];
    }
}

- (FLSortedArrayChange)applyChange:(id)changedItem
{
    FLSortedArrayChange result;
    result.allChanged = NO;
    BOOL matchesFilter = (_filterFunc == nil) || _filterFunc(changedItem);
    if (_sourceArray != nil) {
        matchesFilter &= [_sourceArray indexOfObject:changedItem] != NSNotFound;
    }
    if (_sourceDictionary != nil) {
        BOOL itemExists = NO;
        for (id item in _sourceDictionary.objectEnumerator) {
            if (item == changedItem) {
                itemExists = YES;
                break;
            }
        }
        matchesFilter &= itemExists;
    }

    if ([changedItem isKindOfClass:NSManagedObject.class]) {
        matchesFilter &= !((NSManagedObject*)changedItem).isDeleted;
    }
    result.oldPos = [_items indexOfObject:changedItem];

    if (result.oldPos != NSNotFound) {
        BOOL inOrder = YES;
        if (result.oldPos > 0) {
            inOrder &= (_comparator(_items[result.oldPos - 1], changedItem) == NSOrderedAscending);
        }
        if (result.oldPos < _items.count - 1) {
            inOrder &= (_comparator(changedItem, _items[result.oldPos + 1]) == NSOrderedAscending);
        }
        if (inOrder && matchesFilter) {
            result.newPos = result.oldPos;
            return result;
        }
        [_items removeObjectAtIndex:result.oldPos];
    }

    if (matchesFilter) {
        result.newPos = [_items indexOfObject:changedItem inSortedRange:NSMakeRange(0, _items.count)
                    options:NSBinarySearchingInsertionIndex
                    usingComparator:_comparator];
        [_items insertObject:changedItem atIndex:result.newPos];
    } else {
        result.newPos = NSNotFound;
    }
    return result;
}

- (FLSortedArrayChange)applyChanges:(NSArray *)changes
{
    assert(_items != nil);
    FLSortedArrayChange result;
    result.allChanged = NO;
    result.oldPos = NSNotFound;
    result.newPos = NSNotFound;

    if ((changes == nil) || (changes.count > 1)) {
        [self populateFromArray:_sourceDictionary != nil ?
            _sourceDictionary.allValues : _sourceArray];
        result.allChanged = YES;
        return result;
    }

    assert(changes.count <= 1);

    for (id item in changes) {
        FLSortedArrayChange change = [self applyChange:item];
        if (change.oldPos != change.newPos) {
            if (result.oldPos == result.newPos) {
                result = change;
            } else {
                result.allChanged = YES;
            }
        }
    }

    return result;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
    objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len
{
    return [_items countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (id)objectAtIndexedSubscript:(NSInteger)index
{
    return _items[index];
}

- (NSUInteger)count
{
    return _items.count;
}

- (id)lastObject
{
    return _items.lastObject;
}

- (NSUInteger)indexOfObject:(id)object
{
    return [_items indexOfObject:object
      inSortedRange:NSMakeRange(0, _items.count) options:NSBinarySearchingFirstEqual usingComparator:_comparator];
}

@end
