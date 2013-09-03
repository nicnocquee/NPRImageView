//
//  NPROperationQueue.m
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPROperationQueue.h"

@implementation NPROperationQueue

+ (NPROperationQueue *)processingQueue
{
    static NPROperationQueue *sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[NPROperationQueue alloc] init];
        [sharedQueue setMaxConcurrentOperationCount:4];
    });
    return sharedQueue;
}

@end
