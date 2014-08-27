//
//  FLConversationLists.h
//  Fleep
//
//  Created by Erik Laansoo on 23.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLSortedArray.h"

typedef NS_ENUM(NSInteger,FLConversationListType) {
    FLConversationListInbox = 1,
    FLConversationListPinned = 2,
    FLConversationListArchived = 3,
    FLConversationListLocalFilter = 4,
    FLConversationListServerSearch = 5,
    FLConversationListImplicitDialogs = 6
};

typedef NS_ENUM(NSInteger, FLSearchState) {
    FLSearchStateNoSearch = 0,
    FLSearchStateLocalOnly = 1,
    FLSearchStateSearching = 2,
    FLSearchStateComplete = 3
};

@protocol FLConversationListsDelegate <NSObject>
- (void)list:(FLConversationListType)list itemMovedFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;
- (void)list:(FLConversationListType)list itemAppearedAtIndex:(NSInteger)index;
- (void)list:(FLConversationListType)list itemDisappearedFromIndex:(NSInteger)index;
- (void)listChanged:(FLConversationListType)list;
@end

@interface FLConversationLists : NSObject

@property (nonatomic, readonly) FLSortedArray* inboxList;
@property (nonatomic, readonly) FLSortedArray* pinnedList;
@property (nonatomic, readonly) FLSortedArray* archivedList;
@property (nonatomic, readonly) FLSortedArray* localFilterList;
@property (nonatomic, readonly) FLSortedArray* searchList;
@property (nonatomic, readonly) FLSortedArray* implicitDialogs;

@property (nonatomic, readonly) NSInteger unreadCount;

@property (nonatomic, readonly) FLSearchState searchState;
@property (nonatomic) NSString* searchText;
@property (nonatomic, weak) id<FLConversationListsDelegate> delegate;
@property (nonatomic, readonly) NSSet* contactsMatchingSearch;

+ (FLConversationLists*)conversationLists;
- (FLSortedArray*)getList:(FLConversationListType)list;
- (void)runSearchNow;
- (void)logout;
@end
