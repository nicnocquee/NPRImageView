//
//  NPROperationQueue.m
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPROperationQueue.h"

#import <AFNetworking.h>

@interface NPROperationQueue ()

@property (nonatomic, strong) NSMutableArray *downloadingURLs;

@end

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

- (void)queueProcessingOperation:(NSOperation *)operation urlString:(NSString *)urlString{
    //suspend operation queue
    NSOperationQueue *queue = self;
    [queue setSuspended:YES];
    
    BOOL queued = NO;
    
    AFImageRequestOperation *queuedOperation;
    
    //check for existing operations
    if ([operation isKindOfClass:[AFImageRequestOperation class]]) {
        for (AFImageRequestOperation *op in queue.operations)
        {
            if ([op isKindOfClass:[AFImageRequestOperation class]])
            {
                AFImageRequestOperation *oper = (AFImageRequestOperation *)operation;
                if ([op.request.URL.absoluteString isEqualToString:oper.request.URL.absoluteString])
                {
                    //already queued
                    queuedOperation = op;
                    queued = YES;
                    if ([op isExecuting]) {
                        [queue setSuspended:NO];
                        return;
                    }
                    break;
                }
            }
        }
    }
    
    //make op a dependency of all queued ops
    
    NSInteger maxOperations = ([queue maxConcurrentOperationCount] > 0) ? [queue maxConcurrentOperationCount]: INT_MAX;
    NSInteger index = [queue operationCount] - maxOperations;
    if (index >= 0)
    {
        AFImageRequestOperation *op = (AFImageRequestOperation *)[[queue operations] objectAtIndex:index];
        AFImageRequestOperation *oper = (AFImageRequestOperation *)operation;
        if (queuedOperation) {
            oper = queuedOperation;
        }
        if ([op isReady] && ![op.request.URL.absoluteString isEqualToString:oper.request.URL.absoluteString])
        {
            [oper removeDependency:op];
            [op addDependency:oper];
        }
    }
    
    if (!queued) {
        //add operation to queue
        if (!self.downloadingURLs) {
            self.downloadingURLs = [NSMutableArray array];
        }
        [self.downloadingURLs addObject:urlString];
        [queue addOperation:operation];
    }
    
    //resume queue
    [queue setSuspended:NO];
}

- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString {
    for (NSString *url in self.downloadingURLs) {
        if ([url isEqualToString:urlString]) {
            return YES;
        }
    }
    return NO;
}

- (void)imageDownloadedAtURL:(NSString *)url {
    [self.downloadingURLs removeObject:url];
}

@end
