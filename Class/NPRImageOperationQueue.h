//
//  NPRImageOperationQueue.h
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 10/14/13.
//
//

#import <Foundation/Foundation.h>

extern NSString * const NPRDownloadImageDidSucceedNotification;
extern NSString * const NPRDownloadImageDidFailNotification;

extern NSString * const NPRDidDownloadImageNotificationImageKey;
extern NSString * const NPRImageURLKey;
extern NSString * const NPRDownloadDidFailNotificationErrorKey;
extern NSString * const NPRImageDownloadProgressChangedNotification;
extern NSString * const NPRImageDownloadProgressChangedNotificationBytesReadKey;
extern NSString * const NPRImageDownloadProgressChangedNotificationTotalBytesExpectedKey;
extern NSString * const NPRImageDownloadProgressChangedNotificationBytesTotalBytesReadKey;

@interface NPRImageOperationQueue : NSOperationQueue

+ (instancetype)sharedQueue;

- (void)queueImageURLString:(NSString *)url
        withProcessingBlock:(UIImage *(^)(UIImage *))processingBlock
                   progress:(void(^)(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead))progressBlock
                    success:(void(^)(NSURLRequest *, NSHTTPURLResponse *, UIImage *))successBlock
                    failure:(void(^)(NSURLRequest *, NSHTTPURLResponse *, NSError *))failureBlock;

- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString;

@end
