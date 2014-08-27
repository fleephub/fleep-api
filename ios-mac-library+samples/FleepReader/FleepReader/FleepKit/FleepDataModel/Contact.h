//
//  Contact.h
//  Fleep
//
//  Created by Erik Laansoo on 05.03.13.
//  Copyright (c) 2013 Fleep Technologies Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FLJsonParser.h"

@interface Contact : NSManagedObject <JsonSerialization>

// Stored properties
@property (nonatomic, retain) NSString * account_id;
@property (nonatomic, retain) NSString * display_name;
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSNumber * mk_account_status;
@property (nonatomic, retain) NSNumber * is_hidden_for_add;
@property (nonatomic, retain) NSString * avatar_urls;
@property (nonatomic, retain) NSDate * activity_time;
@property (nonatomic, retain) NSString * dialog_id;
@property (nonatomic, retain) NSNumber* is_dialog_listed;

// Locally calculated properties
@property (nonatomic, readonly) NSString* displayName;
@property (nonatomic, readonly) NSString* shortName;
@property (nonatomic, readonly) NSString* displayNameWithYou;
@property (nonatomic, readonly) NSAttributedString* highlightedName;
@property (nonatomic, readonly) BOOL isFleepContact;
@property (nonatomic, readonly) BOOL isLocalContact;
@property (nonatomic, readonly) NSString* smallAvatarURL;
@property (nonatomic, readonly) NSString* largeAvatarURL;

- (void)applySearchText:(NSString*)searchText;
@end
