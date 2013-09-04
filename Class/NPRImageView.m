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

NSString * const NPRDidSetImageNotification = @"nicnocquee.NPRImageView.didSetImage";

@interface NPRImageView () <UIGestureRecognizerDelegate>

+ (NSOperationQueue *)processingQueue;
+ (NSCache *)processedImageCache;

@property (nonatomic, strong) UIImageView *customImageView;
@property (nonatomic, strong) NSMutableArray *downloadingURLs;

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

@interface NPRDiskCache()

+ (NPRDiskCache *)sharedDiskCache;

@property (strong,nonatomic) NSString *cacheDirectoryName;
@property (strong,nonatomic) NSString *cacheDirectoryPath;
@property (strong, nonatomic) NSMutableDictionary *diskKeys;

@end

#pragma mark - NPRDiskCache

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

#pragma mark - NPRFailDownloadArray

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

#pragma mark - NSOperationQueueObserver

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
        // NSLog(@"%d operations in queue", operations);
        if (operations == 0) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        } else {
            //NSLog(@"In queue: ");
            //for (AFImageRequestOperation *operation in [[NPRImageView processingQueue] operations]) {
            //    NSLog(@" ---- %@", operation.request.URL.absoluteString);
            //}
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        }
    }
}

- (void)dealloc {
    [[NPRImageView processingQueue] removeObserver:self forKeyPath:@"operationCount"];
}

@end

#pragma mark - NPRImageView

@implementation NPRImageView

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
    
    _downloadingURLs = [NSMutableArray array];
    
    self.crossFade = YES;
}

#pragma mark - Gesture

- (void)imageViewTapped:(UITapGestureRecognizer *)gesture {
    if ([[NPRFailDownloadArray array] contains:self.imageContentURL.absoluteString]) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
        [self.messageLabel setHidden:YES];
        [self setNeedsLayout];
        [self performSelector:@selector(queueImageForProcessingForURLString:) withObject:self.imageContentURL.absoluteString afterDelay:1];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.customImageView setFrame:self.bounds];
    
    [self.indicatorView setCenter:CGPointMake(CGRectGetWidth(self.bounds)/2, CGRectGetHeight(self.bounds)/2 - CGRectGetHeight(self.indicatorView.frame)/2 - 5)];
    CGRect frame = self.progressView.frame;
    frame.size.width = 0.8 * CGRectGetWidth(self.bounds);
    self.progressView.frame = frame;
    if (self.indicatorView.hidden) {
        [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.bounds)/2, CGRectGetHeight(self.bounds)/2)];
    } else {
        [self.progressView setCenter:CGPointMake(CGRectGetWidth(self.bounds)/2, CGRectGetHeight(self.bounds)/2 + CGRectGetHeight(self.progressView.frame)/2 + 5 )];
    }
    
    if (!self.messageLabel.hidden) {
        CGRect frame = self.messageLabel.frame;
        frame.size.width = 0.8 * CGRectGetWidth(self.bounds);
        self.messageLabel.frame = frame;
        [self.messageLabel sizeToFit];
        [self.messageLabel setCenter:CGPointMake(CGRectGetWidth(self.bounds)/2, CGRectGetHeight(self.bounds)/2)];
    }
}

#pragma mark - Getter

+ (UIImage *)originalImageForKey:(NSString *)key {
    return [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
}

- (UIImage *)image {
    return self.customImageView.image;
}

- (NPRDiskCache *)sharedCache {
    return [NPRDiskCache sharedDiskCache];
}

- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString {
    for (NSString *url in self.downloadingURLs) {
        if ([url isEqualToString:urlString]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Setter

- (void)setImage:(UIImage *)image {
    self.customImageView.image = image;
}

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage {
    if (![URL.absoluteString isEqualToString:self.imageContentURL.absoluteString])
    {
        [self setCacheKeyWithURL:URL.absoluteString];
        
        [self.messageLabel setText:nil];
        [self.messageLabel setHidden:YES];
        [self.progressView setHidden:YES];
        [self setNeedsLayout];
        
        self.imageContentURL = URL;
        
        self.placeholderImage = placeholderImage;
        
        [self queueImageForProcessingForURLString:URL.absoluteString];
    } else {
        if (![self isDownloadingImageAtURLString:URL.absoluteString]) {
            [self.indicatorView stopAnimating];
        }
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

- (void)continueImageProcessingFromDiskWithKey:(NSString *)key processingKey:(NSString *)processKey urlString:(NSString *)urlString{
    if (!self.shouldHideIndicatorView) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
    }
    
    [self showPlaceholderImage];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        UIImage *image = [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
        if (image) {
            UIImage *im = [self processImage:image key:processKey urlString:urlString];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setProcessedImageOnMainThread:@[im, processKey, urlString]];
            });
            
        } else {
            NSLog(@"");
        }
    });
}

- (void)queueImageForProcessingForURLString:(NSString *)url {
    // check if image exists in cache
    NSString *key = [self cacheKeyWithURL:url];
    UIImage *processedImage = [self cachedProcessImageForKey:key];
    if (processedImage) {
        self.customImageView.image = processedImage;
        [self.indicatorView stopAnimating];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter postNotificationName:NPRDidSetImageNotification object:self];
        });
        return;
    } else {
        // check if processed image exists on disk
        if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:key]) {
            [self continueImageProcessingFromDiskWithKey:key
                                           processingKey:key urlString:url];
            return;
        }
        // check if original image exists on disk
        else {
            if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:url]) {
                [self continueImageProcessingFromDiskWithKey:url
                                               processingKey:key urlString:url];
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
    NSURL *urlToDownload = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlToDownload];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    AFImageRequestOperation *imageOperation = [AFImageRequestOperation imageRequestOperationWithRequest:request imageProcessingBlock:^UIImage *(UIImage *image) {
        UIImage *im = [self processImage:image key:key urlString:url];
        [[NPRDiskCache sharedDiskCache] writeImageToDisk:im key:url];
        return im;
    } success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        [[NPRFailDownloadArray array] removeObject:request.URL.absoluteString];
        [self.downloadingURLs removeObject:request.URL.absoluteString];
        NSString *thisKey = [self cacheKeyWithURL:request.URL.absoluteString];
        [self setProcessedImageOnMainThread:@[image,thisKey,request.URL.absoluteString]];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        [[NPRFailDownloadArray array] addObject:request.URL.absoluteString];
        [self.downloadingURLs removeObject:request.URL.absoluteString];
        if ([request.URL.absoluteString isEqualToString:url]) {
            [self.messageLabel setText:NSLocalizedString(@"Image cannot be downloaded. Tap to reload.", nil)];
            [self.messageLabel setHidden:NO];
            [self.indicatorView stopAnimating];
            [self.progressView setHidden:YES];
            [self setNeedsLayout];
            [self setProcessedImageOnMainThread:@[[NSNull null], request.URL.absoluteString, request.URL.absoluteString]];
        }
    }];
    [imageOperation setAutomaticallyInflatesResponseImage:NO];
    
    @weakify(imageOperation);
    [imageOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        @strongify(self);
        @strongify(imageOperation);
        
        if ([imageOperation.request.URL.absoluteString isEqualToString: self.imageContentURL.absoluteString]) {
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
    }];
    
    [self queueProcessingOperation:imageOperation urlString:url];
}

- (void)queueProcessingOperation:(NSOperation *)operation urlString:(NSString *)urlString{
    //suspend operation queue
    NSOperationQueue *queue = [[self class] processingQueue];
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
        [self.downloadingURLs addObject:urlString];
        [queue addOperation:operation];
    }
    
    //resume queue
    [queue setSuspended:NO];
}

- (UIImage *)processImage:(UIImage *)image key:(NSString *)key urlString:(NSString *)url{
    //check cache
    UIImage *processedImage = (url)?[self cachedProcessImageForKey:key]:nil;
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
    
    return processedImage;
}

- (void)setProcessedImageOnMainThread:(NSArray *)array {
    UIImage *processedImage = [array objectAtIndex:0];
    processedImage = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
    
    //set image
    if ([self.imageContentURL.absoluteString isEqualToString:[array objectAtIndex:2]])
    {
        
        // crossfade
        if (self.crossFade) {
            id animation = objc_msgSend(NSClassFromString(@"CATransition"), @selector(animation));
            objc_msgSend(animation, @selector(setType:), @"kCATransitionFade");
            objc_msgSend(self.layer, @selector(addAnimation:forKey:), animation, nil);
        }
        
        //set processed image
        self.customImageView.image = processedImage;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter postNotificationName:NPRDidSetImageNotification object:self];
        });
        
        if (processedImage) {
            [self.messageLabel setHidden:YES];
        } else {
            [self.messageLabel setHidden:NO];
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
        [self.progressView setHidden:YES];
        [self.indicatorView stopAnimating];
    } else {
        NSLog(@"");
    }
}

+ (void)printOperations {
    for (AFImageRequestOperation *operation in [NPRImageView processingQueue].operations) {
        NSLog(@">> Operation %@ state: %@", operation.request.URL.absoluteString, [[self class] stateString:operation]);
        [operation cancel];
        return;
        for (AFImageRequestOperation *dependecy in operation.dependencies) {
            NSLog(@"     -- Dependency: %@ state: %@", dependecy.request.URL.absoluteString, [[self class] stateString:dependecy]);
        }
    }
}

+ (NSString *)stateString:(AFImageRequestOperation *)operation {
    if ([operation isCancelled]) {
        return @"Cancelled";
    } else if ([operation isExecuting]) {
        return @"executing";
    } else if ([operation isReady]) {
        return @"ready";
    } else if ([operation isPaused]) {
        return @"paused";
    } else if ([operation isFinished]) {
        return @"finished";
    }
    return @"unknown";
}

+ (void)cancelAllOperations {
    [[NPRImageView processingQueue] cancelAllOperations];
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
