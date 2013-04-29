//
//  NPImageView.m
//  NPRImageView
//
//  Created by Nico Prananta on 4/23/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPRImageView.h"

#import "EXTScope.h"
#import "AFImageRequestOperation.h"
#import "UIImage+FX.h"

#import <objc/message.h>

#pragma mark -
#pragma mark - Class extensions

@interface NPRImageView () <UIGestureRecognizerDelegate>

+ (NSOperationQueue *)processingQueue;
+ (NSCache *)processedImageCache;

@property (nonatomic, strong) NSURL *imageContentURL;
@property (nonatomic, strong) UIImageView *customImageView;
@property (nonatomic, strong) NSString *cacheKey;

@end

@interface NSOperationQueueObserver : NSObject

+ (NSOperationQueueObserver *)sharedQueueObserver;
- (void)observe;

@property (nonatomic, getter = isObserving) BOOL observing;

@end

@interface NPRFailDownloadArray : NSObject

@property (nonatomic, strong) NSMutableArray *mutableArray;

+ (NPRFailDownloadArray *)array;
- (BOOL)contains:(id)object;
- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (NSInteger)count;

@end

@interface NPRDiskCache : NSObject

+ (NPRDiskCache *)sharedDiskCache;

@property (strong,nonatomic) NSString *cacheDirectoryName;
@property (strong,nonatomic) NSString *cacheDirectoryPath;
@property (strong, nonatomic) NSMutableDictionary *diskKeys;

@end

#pragma mark -
#pragma mark - Class Implementations

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
        NSData *data = UIImagePNGRepresentation(image);
        NSString *filePath = [self filePathWithKey:key];
        
        NSError *error;
        [data writeToFile:filePath options:NSDataWritingAtomic error:&error];
        if (error) {
            NSLog(@"Cannot write image %@ to path %@", key, filePath);
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

#pragma mark - Path Methods

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

@implementation NSOperationQueueObserver

+ (NSOperationQueueObserver *)sharedQueueObserver {
    static NSOperationQueueObserver *shareObserver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareObserver = [[NSOperationQueueObserver alloc] init];
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
        if (operations == 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    }
}

- (void)dealloc {
    [[NPRImageView processingQueue] removeObserver:self forKeyPath:@"operationCount"];
}

@end

@implementation NPRImageView

#pragma mark - Shared stuff

+ (NSOperationQueue *)processingQueue
{
    static NSOperationQueue *sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [[NSOperationQueue alloc] init];
        [sharedQueue setMaxConcurrentOperationCount:4];
    });
    return sharedQueue;
}

+ (NSCache *)processedImageCache
{
    static NSCache *sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[NSCache alloc] init];
    });
    return sharedCache;
}

#pragma mark - Init

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image
{
    if ((self = [super initWithImage:image]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage
{
    if ((self = [super initWithImage:image highlightedImage:highlightedImage]))
    {
        [self setUp];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setUp
{
    _customImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [_customImageView setBackgroundColor:[UIColor clearColor]];
    [self addSubview:_customImageView];
    
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    _indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [_indicatorView setHidesWhenStopped:YES];
    [_indicatorView setHidden:YES];
    [self addSubview:_progressView];
    [self addSubview:_indicatorView];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [_messageLabel setNumberOfLines:0];
    [_messageLabel setBackgroundColor:[UIColor clearColor]];
    [_messageLabel setFont:[UIFont boldSystemFontOfSize:17]];
    [_messageLabel setTextColor:[UIColor darkGrayColor]];
    [_messageLabel setTextAlignment:NSTextAlignmentCenter];
    [self addSubview:_messageLabel];
    
    [[NSOperationQueueObserver sharedQueueObserver] observe];
    
    [[NPRDiskCache sharedDiskCache] setCacheDirectoryName:@"nprimageviewCache"];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)];
    [tapGesture setDelegate:self];
    tapGesture.cancelsTouchesInView = NO;
    [_customImageView setOpaque:NO];
    [_customImageView setUserInteractionEnabled:YES];
    [self addGestureRecognizer:tapGesture];
    [self setUserInteractionEnabled:YES];
}

#pragma mark - Gesture

- (void)imageViewTapped:(UITapGestureRecognizer *)gesture {
    if ([[NPRFailDownloadArray array] contains:self.imageContentURL.absoluteString]) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
        [self.messageLabel setHidden:YES];
        [self setNeedsLayout];
        [self performSelector:@selector(queueImageForProcessing) withObject:nil afterDelay:1];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.customImageView setFrame:self.bounds];
    
    if (!self.indicatorView.hidden) {
        [self.indicatorView setCenter:CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2 - CGRectGetHeight(self.indicatorView.frame)/2 - 5)];
    }
    
    if (!self.progressView.hidden) {
        CGRect frame = self.progressView.frame;
        frame.size.width = 0.8 * CGRectGetWidth(self.frame);
        self.progressView.frame = frame;
        if (self.indicatorView.hidden) {
            [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2)];
        } else {
            [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2 + CGRectGetHeight(self.progressView.frame)/2 + 5 )];
        }
    }
    
    if (!self.messageLabel.hidden) {
        CGRect frame = self.messageLabel.frame;
        frame.size.width = 0.8 * CGRectGetWidth(self.frame);
        self.messageLabel.frame = frame;
        [self.messageLabel sizeToFit];
        [self.messageLabel setCenter:CGPointMake(CGRectGetWidth(self.frame)/2, CGRectGetHeight(self.frame)/2)];
    }
}

#pragma mark - Getter

+ (UIImage *)originalImageForKey:(NSString *)key {
    return [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
}

#pragma mark - Setter

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage {
    if (![URL isEqual:self.imageContentURL])
    {
        [self setCacheKeyWithURL:URL.absoluteString];
        
        [self.messageLabel setText:nil];
        [self.messageLabel setHidden:YES];
        [self.progressView setHidden:YES];
        [self setNeedsLayout];
        
        self.imageContentURL = URL;
        
        self.placeholderImage = placeholderImage;
        
        [self queueImageForProcessing];
    }
}

- (void)setProgressView:(UIProgressView *)progressView {
    if (_progressView != progressView) {
        [_progressView removeFromSuperview];
        _progressView = progressView;
        [self addSubview:_progressView];
    }
}

- (void)setIndicatorView:(UIActivityIndicatorView *)indicatorView {
    if (_indicatorView != indicatorView) {
        [_indicatorView removeFromSuperview];
        _indicatorView = indicatorView;
        [self addSubview:_indicatorView];
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (self.contentMode != contentMode)
    {
        super.contentMode = contentMode;
        [self.customImageView setContentMode:contentMode];
        [self setNeedsLayout];
    }
}

#pragma mark - Image Processing

- (void)showPlaceholderImage {
    self.customImageView.image = self.placeholderImage;
}

- (void)continueImageProcessingFromDiskWithKey:(NSString *)key processingKey:(NSString *)processKey {
    if (!self.shouldHideIndicatorView) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
    }
    
    [self showPlaceholderImage];
    @weakify(self);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @strongify(self);
        UIImage *image = [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
        if (image) {
            [self processImage:image key:processKey];
        }
    });
}

- (void)queueImageForProcessing {
    // check if image exists in cache
    UIImage *processedImage = [self cachedProcessImageForKey:self.cacheKey];
    if (processedImage) {
        self.customImageView.image = processedImage;
        return;
    } else {
        // check if processed image exists on disk
        if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:self.cacheKey]) {
            [self continueImageProcessingFromDiskWithKey:self.cacheKey
                                           processingKey:self.cacheKey];
            return;
        }
        // check if original image exists on disk
        else {
            if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:self.imageContentURL.absoluteString]) {
                [self continueImageProcessingFromDiskWithKey:self.imageContentURL.absoluteString
                                               processingKey:self.cacheKey];
                return;
            }
        }
        
    }
    
    // image cannot be found on disk nor cache. Let's download it.
    [self showPlaceholderImage];
    if (!self.shouldHideIndicatorView) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
    }
    [self.progressView setProgress:0];
    [self.progressView setHidden:NO];
    
    @weakify(self);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.imageContentURL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    AFImageRequestOperation *imageOperation = [[AFImageRequestOperation alloc] initWithRequest:request];
    @weakify(imageOperation);
    
    [imageOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        @strongify(self);
        @strongify(imageOperation);
        
        if ([imageOperation.request.URL isEqual: self.imageContentURL]) {
            if (![self cachedProcessImageForKey:imageOperation.request.URL.absoluteString]) {
                if ((float)totalBytesRead/(float)totalBytesExpectedToRead  < 1) {
                    [self.messageLabel setText:nil];
                    [self.messageLabel setHidden:YES];
                    
                    if (!self.shouldHideIndicatorView) {
                        [self.indicatorView startAnimating];
                        [self.indicatorView setHidden:NO];
                    }
                }
                [self.progressView setHidden:NO];
                [self setNeedsLayout];
                
                [self.progressView setProgress:(float)totalBytesRead/(float)totalBytesExpectedToRead animated:NO];
                if (totalBytesRead == totalBytesExpectedToRead) {
                    [self.progressView setHidden:YES];
                }
            }
        }
    }];
    
    [imageOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[NPRFailDownloadArray array] removeObject:operation.request.URL.absoluteString];
        @strongify(self);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (responseObject) {
                [[NPRDiskCache sharedDiskCache] writeImageToDisk:responseObject key:operation.request.URL.absoluteString];
                [self processImage:responseObject key:[self cacheKeyWithURL:operation.request.URL.absoluteString]];
            } else {
                [self setProcessedImageOnMainThread:@[[NSNull null], operation.request.URL.absoluteString, operation.request.URL.absoluteString]];
            }
        });
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[NPRFailDownloadArray array] addObject:operation.request.URL.absoluteString];
        if ([operation.request.URL.absoluteString isEqualToString:self.imageContentURL.absoluteString]) {
            @strongify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.messageLabel setText:NSLocalizedString(@"Image cannot be downloaded. Tap to reload.", nil)];
                [self.messageLabel setHidden:NO];
                [self.indicatorView stopAnimating];
                [self.progressView setHidden:YES];
                [self setNeedsLayout];
            });
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self setProcessedImageOnMainThread:@[[NSNull null], operation.request.URL.absoluteString, operation.request.URL.absoluteString]];
            });
        }
    }];
    
    [self queueProcessingOperation:imageOperation];
}

- (void)queueProcessingOperation:(NSOperation *)operation {
    //suspend operation queue
    NSOperationQueue *queue = [[self class] processingQueue];
    [queue setSuspended:YES];
    
    //check for existing operations
    if ([operation isKindOfClass:[AFImageRequestOperation class]]) {
        for (AFImageRequestOperation *op in queue.operations)
        {
            if ([op isKindOfClass:[AFImageRequestOperation class]])
            {
                AFImageRequestOperation *oper = (AFImageRequestOperation *)operation;
                if ([op.request isEqual:oper.request])
                {
                    //already queued
                    [queue setSuspended:NO];
                    return;
                }
            }
        }
    }
    
    //make op a dependency of all queued ops
    NSInteger maxOperations = ([queue maxConcurrentOperationCount] > 0) ? [queue maxConcurrentOperationCount]: INT_MAX;
    NSInteger index = [queue operationCount] - maxOperations;
    if (index >= 0)
    {
        NSOperation *op = [[queue operations] objectAtIndex:index];
        if (![op isExecuting])
        {
            [operation removeDependency:op];
            [op addDependency:operation];
        }
    }
    
    //add operation to queue
    [queue addOperation:operation];
    
    //resume queue
    [queue setSuspended:NO];
}

- (void)processImage:(UIImage *)image key:(NSString *)key {
    //check cache
    UIImage *processedImage = [self cachedProcessImageForKey:key];
    if (!processedImage)
    {
        if (image) {
            //crop and scale image
            processedImage = [image imageCroppedAndScaledToSize:self.bounds.size
                                                    contentMode:self.contentMode
                                                       padToFit:NO];
        } else {
            processedImage = self.placeholderImage;
        }
    }
    
    if (processedImage)
    {
        //cache image
        [self cacheProcessedImage:processedImage forKey:key];
    }
    
    // set image on main thread
    [self setProcessedImageOnMainThread:@[processedImage?:[NSNull null], key]];
}

- (void)setProcessedImageOnMainThread:(NSArray *)array {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *cacheKey = [array objectAtIndex:1];
        UIImage *processedImage = [array objectAtIndex:0];
        processedImage = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
        
        //set image
        if ([self.cacheKey isEqualToString:cacheKey])
        {
            
            // crossfade
            id animation = objc_msgSend(NSClassFromString(@"CATransition"), @selector(animation));
            objc_msgSend(animation, @selector(setType:), @"kCATransitionFade");
            objc_msgSend(self.layer, @selector(addAnimation:forKey:), animation, nil);
            
            //set processed image
            self.customImageView.image = processedImage;
            
            if (processedImage) {
                [self.messageLabel setHidden:YES];
            } else {
                [self.messageLabel setHidden:NO];
                [self setNeedsLayout];
                [self layoutIfNeeded];
            }
            [self.progressView setHidden:YES];
            [self.indicatorView stopAnimating];
        }
    });
}


#pragma mark - Cache

- (void)setCacheKeyWithURL:(NSString *)url {
    self.cacheKey = [self cacheKeyWithURL:url];
}

- (NSString *)cacheKeyWithURL:(NSString *)url {
    return [NSString stringWithFormat:@"%@_%i", url, self.contentMode];
}

- (UIImage *)cachedProcessImageForKey:(NSString *)key {
    return [[[self class] processedImageCache] objectForKey:key];
}

- (void)cacheProcessedImage:(UIImage *)processedImage forKey:(NSString *)cacheKey {
    [[[self class] processedImageCache] setObject:processedImage forKey:cacheKey];
    [[NPRDiskCache sharedDiskCache] writeImageToDisk:processedImage key:cacheKey];
}

@end
