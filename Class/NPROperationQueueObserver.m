//
//  NPROperationQueueObserver.m
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPROperationQueueObserver.h"

#import "NPRImageView.h"

@implementation NPROperationQueueObserver

+ (NPROperationQueueObserver *)sharedQueueObserver {
    static NPROperationQueueObserver *shareObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareObserver = [[NPROperationQueueObserver alloc] init];
    });
    return shareObserver;
}

- (void)observe {
    if (!self.isObserving) {
        NSOperationQueue *sharedQueue = [NPRImageView processingQueue];
        [sharedQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:NULL];
        self.observing = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationCount"]) {
        int operations = [[change objectForKey:@"new"] intValue];
        // NSLog(@"%d operations in queue", operations);
        if (operations == 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        } else {
            //NSLog(@"In queue: ");
            //for (AFImageRequestOperation *operation in [[NPRImageView processingQueue] operations]) {
            //    NSLog(@" ---- %@", operation.request.URL.absoluteString);
            //}
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    }
}

- (void)dealloc {
    [[NPRImageView processingQueue] removeObserver:self forKeyPath:@"operationCount"];
}

@end
