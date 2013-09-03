//
//  NPRDiskCache.h
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPRDiskCache : NSObject

@property (strong,nonatomic) NSString *cacheDirectoryName;
@property (strong,nonatomic) NSString *cacheDirectoryPath;
@property (strong, nonatomic) NSMutableDictionary *diskKeys;

+ (NPRDiskCache *)sharedDiskCache;
- (BOOL)imageExistsOnDiskWithKey:(NSString *)key;
- (UIImage *)imageFromDiskWithKey:(NSString *)key;
- (void)writeImageToDisk:(NSData *)data key:(NSString *)key;

@end
