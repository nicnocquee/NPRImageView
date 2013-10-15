//
//  NPRDiskCache.m
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 10/14/13.
//
//

#import "NPRDiskCache.h"


@implementation NPRDiskCache

+ (NPRDiskCache *)sharedDiskCache {
    static NPRDiskCache *sharedDiskCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDiskCache = [[NPRDiskCache alloc] init];
    });
    return sharedDiskCache;
}

- (void)writeImageToDisk:(UIImage *)image key:(NSString *)key{
    NSString *hashKey = [NSString stringWithFormat:@"%d", [key hash]];
    if (![self imageExistsOnDiskWithKey:key]) {
        NSData *data = UIImageJPEGRepresentation(image, 1);
        NSString *filePath = [self filePathWithKey:key];
        
        NSError *error;
        if (![data writeToFile:filePath options:0 error:&error]) {
            if (error) {
                NSLog(@"Cannot write image %@ to path %@", key, filePath);
            }
        } else {
            [self.diskKeys setObject:[NSNull null] forKey:hashKey];
        }
    }
}

- (NSString *)filePathWithKey:(NSString *)key{
    return [self.cacheDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", [key hash]]];
}

- (BOOL)imageExistsOnDiskWithKey:(NSString *)key{
    NSString *hashedKey = [NSString stringWithFormat:@"%d", [key hash]];
	if(self.diskKeys) return [self.diskKeys objectForKey:hashedKey]==nil ? NO : YES;
    return [[NSFileManager defaultManager] fileExistsAtPath:hashedKey];
}

- (UIImage*)imageFromDiskWithKey:(NSString*)key{
	NSData *data = [NSData dataWithContentsOfFile:[self filePathWithKey:key]];
	return [[UIImage alloc] initWithData:data];
}

- (void)setupFolderDirectory {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *path = self.cacheDirectoryPath;
	
	BOOL isDirectory = NO;
	BOOL folderExists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory;
	
	if (!folderExists){
		NSError *error = nil;
		[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	}
}

- (void)setCacheDirectoryName:(NSString *)cacheDirectoryName {
    if (_cacheDirectoryName != cacheDirectoryName) {
        _cacheDirectoryName = cacheDirectoryName;
        if(!self.cacheDirectoryPath){
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *str = [documentsDirectory stringByAppendingPathComponent:_cacheDirectoryName];
            self.cacheDirectoryPath = str;
        }
        
        [self setupFolderDirectory];
        
        NSError* error = nil;
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDirectoryPath error:&error];
        
        if(error) return;
        
        NSMutableArray *ar = [NSMutableArray arrayWithCapacity:files.count];
        for(NSObject *obj in files)
            [ar addObject:[NSNull null]];
        
        self.diskKeys = [[NSMutableDictionary alloc] initWithObjects:ar forKeys:files];
    }
}

@end