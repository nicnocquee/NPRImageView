//
//  NPROperationQueue.h
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPROperationQueue : NSOperationQueue

+ (NPROperationQueue *)processingQueue;

- (void)queueProcessingOperation:(NSOperation *)operation urlString:(NSString *)urlString;
- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString;
- (void)imageDownloadedAtURL:(NSString *)url;

@end
