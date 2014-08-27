//
//  Conversation+Sync.h
//  Fleep
//
//  Created by Erik Laansoo on 04.04.14.
//  Copyright (c) 2014 Fleep Technologies Ltd. All rights reserved.
//

#import "Conversation.h"
#import "FLApiRequest.h"

@interface Conversation (Sync)
- (FLApiRequest*) getMessageLoadRequest;
- (FLApiRequest*) getMarkUnreadRequest;
- (FLApiRequest*) getMarkReadRequest;
- (FLApiRequest*) getSetAlertLevelRequest;
- (FLApiRequest*) getHideRequest;
- (FLApiRequest*) getSetPinOrderRequest;
- (FLApiRequest*) getSetTopicRequest;
- (FLApiRequest*) getMessageSyncRequest;
- (FLApiRequest*) getFileLoadRequest;
- (FLApiRequest*) getPinLoadRequest;
- (FLApiRequest*) getContextLoadRequestAroundMessageNr:(NSInteger)messageNr;
- (FLApiRequest*) getFillGapRequestBefore:(BOOL)before messageNr:(NSInteger)messageNr;
@end
