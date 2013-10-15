//
//  NPRImageOperationQueue.m
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 10/14/13.
//
//

#import "NPRImageOperationQueue.h"

#import <AFImageRequestOperation.h>
#import <EXTScope.h>

NSString * const NPRDownloadImageDidSucceedNotification = @"nprimageview.NPRDownloadImageDidSucceedNotification";
NSString * const NPRDownloadImageDidFailNotification = @"nprimageview.NPRDownloadImageDidFailNotification";
NSString * const NPRImageDownloadProgressChangedNotification = @"nprimageview.NPRImageDownloadProgressChangedNotification";

NSString * const NPRDidDownloadImageNotificationImageKey = @"nprimageview.NPRDidDownloadImageNotificationImageKey";
NSString * const NPRImageURLKey = @"nprimageview.NPRImageURLKey";
NSString * const NPRDownloadDidFailNotificationErrorKey = @"nprimageview.NPRDownloadDidFailNotificationErrorKey";

NSString * const NPRImageDownloadProgressChangedNotificationBytesReadKey = @"nprimageview.NPRImageDownloadProgressChangedNotificationBytesReadKey";
NSString * const NPRImageDownloadProgressChangedNotificationTotalBytesExpectedKey = @"nprimageview.NPRImageDownloadProgressChangedNotificationTotalBytesExpectedKey";
NSString * const NPRImageDownloadProgressChangedNotificationBytesTotalBytesReadKey = @"nprimageview.NPRImageDownloadProgressChangedNotificationBytesTotalBytesReadKey";

@interface NPRImageOperationQueue ()

@property (nonatomic, strong) NSMutableArray *downloadingURLs;

@end

@implementation NPRImageOperationQueue

+ (instancetype)sharedQueue {
    static id sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[[self class] alloc] init];
        [sharedQueue setMaxConcurrentOperationCount:4];
    });
    return sharedQueue;
}

- (void)queueImageURLString:(NSString *)url
        withProcessingBlock:(UIImage *(^)(UIImage *))processingBlock
                   progress:(void(^)(NSUInteger, long long, long long))progressBlock
                    success:(void(^)(NSURLRequest *, NSHTTPURLResponse *, UIImage *))successBlock
                    failure:(void(^)(NSURLRequest *, NSHTTPURLResponse *, NSError *))failureBlock {
    if (!self.downloadingURLs) {
        self.downloadingURLs = [NSMutableArray array];
    }
    if ([self.downloadingURLs containsObject:url]) {
        return;
    }
    
    NSURL *urlToDownload = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlToDownload];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    
    AFImageRequestOperation *imageOperation = [AFImageRequestOperation imageRequestOperationWithRequest:request
                                                                                   imageProcessingBlock:processingBlock
                                                                                                success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                                                                                    [self.downloadingURLs removeObject:request.URL.absoluteString];
                                                                                                    if (image) {
                                                                                                        successBlock(request, response, image);
                                                                                                        [[NSNotificationCenter defaultCenter] postNotificationName:NPRDownloadImageDidSucceedNotification object:nil userInfo:@{NPRDidDownloadImageNotificationImageKey: image, NPRImageURLKey:request.URL}];
                                                                                                    }
                                                                                                } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                                                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                        [self.downloadingURLs removeObject:request.URL.absoluteString];
                                                                                                        failureBlock(request, response, error);
                                                                                                        [[NSNotificationCenter defaultCenter] postNotificationName:NPRDownloadImageDidFailNotification object:nil userInfo:@{NPRDownloadDidFailNotificationErrorKey: error, NPRImageURLKey:request.URL}];
                                                                                                    });
                                                                                                }];
    
    [imageOperation setAutomaticallyInflatesResponseImage:NO];
    
    [imageOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NPRImageDownloadProgressChangedNotification object:nil userInfo:@{NPRImageURLKey: urlToDownload, NPRImageDownloadProgressChangedNotificationBytesReadKey:@(bytesRead), NPRImageDownloadProgressChangedNotificationBytesTotalBytesReadKey:@(totalBytesRead), NPRImageDownloadProgressChangedNotificationTotalBytesExpectedKey:@(totalBytesExpectedToRead)}];
        });
    }];
    
    [self queueProcessingOperation:imageOperation urlString:url];
}

- (void)queueProcessingOperation:(NSOperation *)operation urlString:(NSString *)urlString{
    //suspend operation queue
    NSOperationQueue *queue = self;
    [queue setSuspended:YES];
    
    BOOL queued = NO;
    
    AFImageRequestOperation *queuedOperation = nil;
    
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
    
    //    NSInteger maxOperations = ([queue maxConcurrentOperationCount] > 0) ? [queue maxConcurrentOperationCount]: INT_MAX;
    //    NSInteger index = [queue operationCount] - maxOperations;
    //    if (index >= 0)
    //    {
    //        AFImageRequestOperation *op = (AFImageRequestOperation *)[[queue operations] objectAtIndex:index];
    //        AFImageRequestOperation *oper = (AFImageRequestOperation *)operation;
    //        if (queuedOperation) {
    //            oper = queuedOperation;
    //        }
    //        if (![op isExecuting] && ![op.request.URL.absoluteString isEqualToString:oper.request.URL.absoluteString])
    //        {
    //            [oper removeDependency:op];
    //            [op addDependency:oper];
    //        }
    //    }
    
    if (!queued) {
        //add operation to queue
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

@end
