//
//  NPRDiskCache.h
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 10/14/13.
//
//

#import <Foundation/Foundation.h>

@interface NPRDiskCache : NSObject

@property (strong,nonatomic) NSString *cacheDirectoryName;
@property (strong,nonatomic) NSString *cacheDirectoryPath;
@property (strong, nonatomic) NSMutableDictionary *diskKeys;

+ (NPRDiskCache *)sharedDiskCache;
- (BOOL)imageExistsOnDiskWithKey:(NSString *)key;
- (UIImage*)imageFromDiskWithKey:(NSString*)key;
- (void)writeImageToDisk:(UIImage *)image key:(NSString *)key;
@end