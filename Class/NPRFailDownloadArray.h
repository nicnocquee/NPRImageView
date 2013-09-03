//
//  NPRFailDownloadArray.h
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPRFailDownloadArray : NSObject

@property (nonatomic, strong) NSMutableArray *mutableArray;

+ (NPRFailDownloadArray *)array;
- (BOOL)contains:(id)object;
- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (NSInteger)count;

@end