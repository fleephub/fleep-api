//
//  FLConversationLists.m
//  Fleep
//
//  Created by Erik Laansoo on 23.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "FLConversationLists.h"
#import "FLDataModel.h"
#import "FLApi.h"
#import "FLApi+Actions.h"
#import "ConversationInternal.h"
#import "FLDataModelInternal.h"

#define SERVER_SEARCH_MIN_LENGTH 1

FLConversationLists* _conversationLists = nil;

@implementation FLConversationLists
{
    FLSortedArray* _inboxList;
    FLSortedArray* _pinnedList;
    FLSortedArray* _archivedList;
    FLSortedArray* _implicitDialogs;
    FLSortedArray* _searchList;
    FLSortedArray* _localFilterList;

    NSInteger _unreadCount;

    NSString* _searchText;
    NSSet* _contactsMatchingSearch;
    __weak id<FLConversationListsDelegate> _delegate;
    NSInteger _searchIndex;
}

@synthesize pinnedList = _pinnedList;
@synthesize inboxList = _inboxList;
@synthesize archivedList = _archivedList;
@synthesize localFilterList = _localFilterList;
@synthesize searchList = _searchList;
@synthesize implicitDialogs = _implicitDialogs;
@synthesize unreadCount = _unreadCount;
@synthesize delegate = _delegate;
@synthesize contactsMatchingSearch = _contactsMatchingSearch;

+ (FLConversationLists*)conversationLists
{
    assert(_conversationLists != nil);
    return _conversationLists;
}

- (void)logout
{
    _conversationLists = nil;
}

- (id)init
{
    if (self = [super init]) {
        FLDataModel* dm = [FLDataModel dataModel];
        _conversationLists = self;
        _inboxList = [[FLSortedArray alloc] init];
        _inboxList.filterFunc = ^BOOL(Conversation* c) {
            return !c.isHidden;
        };
        _inboxList.comparator = ^NSComparisonResult (Conversation* obj1, Conversation* obj2) {
            return [obj1 compareTimestamp:obj2];
        };
        _inboxList.sourceDictionary = dm.conversations;
        _pinnedList = [[FLSortedArray alloc] init];
        _pinnedList.filterFunc = ^BOOL(Conversation *c) {
            return c.pin_weight != nil;
        };
        _pinnedList.comparator = ^NSComparisonResult(Conversation* obj1, Conversation* obj2) {
            return [obj1 comparePinOrder:obj2];
        };
        _pinnedList.sourceDictionary = dm.conversations;
        _archivedList = [[FLSortedArray alloc] init];
        _archivedList.filterFunc = ^BOOL(Conversation* c) {
            return c.isHidden;
        };
        _archivedList.comparator = ^NSComparisonResult (Conversation* obj1, Conversation* obj2) {
            return [obj1 compareTimestamp:obj2];
        };
        _archivedList.sourceDictionary = dm.conversations;
        _implicitDialogs = [[FLSortedArray alloc] init];
        _implicitDialogs.filterFunc = ^BOOL(Contact* c) {
            return c.is_dialog_listed.boolValue && (c.highlightedName != nil);
        };
        _implicitDialogs.comparator = ^NSComparisonResult(Contact* c1, Contact* c2) {
            return [c1.displayName compare:c2.displayName];
        };
        _implicitDialogs.sourceDictionary = dm.contacts;
        _localFilterList = [[FLSortedArray alloc] init];
        _localFilterList.filterFunc = ^BOOL(Conversation *c) {
            return c.filterMatch != nil;
        };
        _localFilterList.comparator = ^NSComparisonResult(Conversation* c1, Conversation* c2) {
            if ((c1.filterMatch.topic != nil) && (c2.filterMatch.topic == nil)) {
                return NSOrderedAscending;
            } else if ((c1.filterMatch.topic == nil) && (c2.filterMatch.topic != nil)) {
                return NSOrderedDescending;
            } else
                return [c1 compareTimestamp:c2];
        };

        _searchList = [[FLSortedArray alloc] init];
        _searchList.filterFunc = nil;
        _searchList.comparator = ^NSComparisonResult(Message* m1, Message* m2) {
            if (m1.searchWeight > m2.searchWeight) {
                return NSOrderedAscending;
            } else if (m1.searchWeight < m2.searchWeight) {
                return NSOrderedDescending;
            } else
                return [m2.posted_time compare:m1.posted_time]; // reverse message number order
        };
    }
    return self;
}

- (NSSet*)contactsMatchingSearch
{
    return _contactsMatchingSearch;
}

- (BOOL)serverSearchAvailable
{
    return (_searchText.length >= SERVER_SEARCH_MIN_LENGTH) &&
        (_localFilterList.count < 100);
}

- (FLSearchState)searchState
{
    if (_searchText == nil) {
        return FLSearchStateNoSearch;
    }

    if (![self serverSearchAvailable]) {
        return FLSearchStateLocalOnly;
    }

    return _searchIndex > 0 ? FLSearchStateSearching : FLSearchStateComplete;
}

- (FLSortedArray*)getList:(FLConversationListType)list
{
    switch (list) {
        case FLConversationListInbox: return _inboxList;
        case FLConversationListPinned: return _pinnedList;
        case FLConversationListArchived: return _archivedList;
        case FLConversationListServerSearch: return _searchList;
        case FLConversationListLocalFilter: return _localFilterList;
        case FLConversationListImplicitDialogs: return _implicitDialogs;
        default:assert(false);
    }
}

- (void)updateList:(FLConversationListType)list withChanges:(NSArray*)changes
{
    FLSortedArray* l = [self getList:list];
    FLSortedArrayChange change = [l applyChanges:changes];
    if (_delegate == nil) {
        return;
    }

    if (change.allChanged) {
        [_delegate listChanged:list];
        return;
    }

    if (change.newPos == change.oldPos) {
        return;
    }

    if (change.oldPos == NSNotFound) {
        [_delegate list:list itemAppearedAtIndex:change.newPos];
        return;
    }

    if (change.newPos == NSNotFound) {
        [_delegate list:list itemDisappearedFromIndex:change.oldPos];
        return;
    }

    [_delegate list:list itemMovedFromIndex:change.oldPos toIndex:change.newPos];
}

- (void)updateFilteredListsWithChanges:(NSDictionary*)changes
{
    NSArray* changeArray = changes.allValues;

    [self updateList:FLConversationListInbox withChanges:changeArray];
    [self updateList:FLConversationListPinned withChanges:changeArray];
    [self updateList:FLConversationListArchived withChanges:changeArray];
    if (_searchText != nil) {
        [self updateList:FLConversationListLocalFilter withChanges:changeArray];
    }

    NSInteger newUnreadCount = 0;
    for (Conversation* c in self.inboxList) {
        if (!c.isNotifyingUnread) {
            break;
        }
        newUnreadCount++;
    }

    if (newUnreadCount != self.unreadCount) {
        [self willChangeValueForKey:@"unreadCount"];
        _unreadCount = newUnreadCount;
        [self didChangeValueForKey:@"unreadCount"];
    }
}

- (NSString*)searchText
{
    return _searchText;
}

- (void)searchEndedWithIndex:(NSInteger)index
{
    if (index == _searchIndex) {
        [self willChangeValueForKey:@"searchState"];
        _searchIndex = 0;
        [self didChangeValueForKey:@"searchState"];
        FLLogDebug(@"FLDataModel: SearchState = %ld", (long)self.searchState);
    }
}

- (void)updateContactsMatchingSearch
{
    __block NSMutableSet* contactsMatchingSearch = nil;

    if ((_searchText != nil) &&(_searchText.length > 0)) {
        contactsMatchingSearch = [[NSMutableSet alloc] init];
    }

    [[FLDataModel dataModel].contacts enumerateKeysAndObjectsUsingBlock:^(NSString* key, Contact* c, BOOL *stop) {
        [c applySearchText:_searchText];
        if ((contactsMatchingSearch != nil) && (c.highlightedName != nil)) {
            [contactsMatchingSearch addObject:key];
        }
    }];

    _contactsMatchingSearch = contactsMatchingSearch;
}

- (void)setSearchText:(NSString *)searchText
{
    _searchText = searchText;
    if ((_searchText != nil) && (_searchText.length == 0)) {
        _searchText = nil;
    }

    [self updateContactsMatchingSearch];

    [[FLDataModel dataModel].conversations enumerateKeysAndObjectsUsingBlock:^(NSString* key, Conversation* c, BOOL *stop) {
        c.searchText = _searchText;
    }];

    if (_searchList.sourceArray != nil) {
        _searchList.sourceArray = nil;
        [_delegate listChanged:FLConversationListServerSearch];
    }

    _implicitDialogs.sourceDictionary = nil;
    _implicitDialogs.sourceDictionary = [FLDataModel dataModel].contacts;
    [_delegate listChanged:FLConversationListImplicitDialogs];

    if (_searchText == nil) {
        _localFilterList.sourceDictionary = nil;
        _searchIndex = 0;
        [_delegate listChanged:FLConversationListLocalFilter];
    } else {
        _localFilterList.sourceDictionary = nil;
        _localFilterList.sourceDictionary = [FLDataModel dataModel].conversations;
        [_delegate listChanged:FLConversationListLocalFilter];

        if ([self serverSearchAvailable]) {
            [self performSelector:@selector(startSearch:) withObject:@(++_searchIndex)
                afterDelay:1.0f];
        } else {
            _searchIndex = 0;
        }
    }

    [self willChangeValueForKey:@"searchState"];
    [self didChangeValueForKey:@"searchState"];
    FLLogDebug(@"FLDataModel: SearchState = %ld", (long)self.searchState);
}

- (void)runSearchNow
{
    [self startSearch:@(++_searchIndex)];
}

- (void)startSearch:(NSNumber*)index
{
    if (index.integerValue != _searchIndex) {
        return;
    }

    NSInteger searchIndex = index.integerValue;
    __block NSMutableArray* results = [[NSMutableArray alloc] init];

    [[FLApi api] searchMessages:_searchText inConversation:nil
        onResult:^(NSString *conversationId, NSInteger messageNr) {
            Conversation* c = [[FLDataModel dataModel] conversationChangedWithId:conversationId];
            Message* m = [c messageByNumber:messageNr searchOutsideSyncRange:YES];
            if (m != nil) {
                [c addMatchingMessage:m];
                [results addObject:m];
            }
        } onSuccess:^{
            _searchList.sourceArray = results;
            [_delegate listChanged:FLConversationListServerSearch];
            [self searchEndedWithIndex:searchIndex];
        } onError:^(NSError *error) {
            [self searchEndedWithIndex:searchIndex];
        }
    ];
}

- (void)notifyContactsChanged:(NSSet*)changedContacts
{
    NSArray* contacts = [changedContacts.allObjects arrayByMappingObjectsUsingBlock:^id(NSString* contactId) {
        return [[FLDataModel dataModel] contactFromId:contactId];
    }];

    for (Contact* c in contacts) {
        [c applySearchText:_searchText];
    }

    [self updateList:FLConversationListImplicitDialogs withChanges:contacts];
}


@end
