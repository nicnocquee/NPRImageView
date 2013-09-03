//
//  NPRFailDownloadArray.m
//  NPRImageView
//
//  Created by Nico Prananta on 9/3/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPRFailDownloadArray.h"

@implementation NPRFailDownloadArray

+ (NPRFailDownloadArray *)array {
    static NPRFailDownloadArray *failArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        failArray = [[NPRFailDownloadArray alloc] init];
    });
    return failArray;
}

- (id)init {
    self = [super init];
    if (self) {
        _mutableArray = [NSMutableArray array];
    }
    return self;
}

- (BOOL)contains:(id)object {
    @synchronized(self) {
        return [self.mutableArray containsObject:object];
    }
}

- (void)addObject:(id)object {
    @synchronized(self) {
        if (![self.mutableArray containsObject:object]) {
            [self.mutableArray addObject:object];
        }
    }
}

- (void)removeObject:(id)object {
    @synchronized(self) {
        if ([self.mutableArray containsObject:object]) {
            [self.mutableArray removeObject:object];
        }
    }
}

- (NSInteger)count {
    @synchronized(self) {
        return self.mutableArray.count;
    }
}

@end
