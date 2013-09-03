//
//  NPROperationQueueObserver.h
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPROperationQueueObserver : NSObject

@property (nonatomic, getter = isObserving) BOOL observing;

+ (NPROperationQueueObserver *)sharedQueueObserver;
- (void)observe;

@end
