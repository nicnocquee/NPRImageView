//
//  NPImageView.m
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 4/23/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "NPRImageView.h"

#import "NPRDiskCache.h"
#import "NPRImageOperationQueue.h"
#import "EXTScope.h"
#import "AFImageRequestOperation.h"
#import "UIImage+FX.h"

#import <objc/message.h>

NSString * const NPRDidSetImageNotification = @"nicnocquee.NPRImageView.didSetImage";

@interface NPRImageView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;

+ (NSCache *)processedImageCache;
+ (void)printOperations;

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

#pragma mark - NPRImageView

@implementation NPRImageView

#pragma mark - Singletons

+ (NSCache *)processedImageCache
{
    static NSCache *sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[NSCache alloc] init];
    });
    return sharedCache;
}

+ (NSOperationQueue *)imageProcessingQueue {
    static NSOperationQueue *sharedImageProcessingQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedImageProcessingQueue = [[NSOperationQueue alloc] init];
        [sharedImageProcessingQueue setMaxConcurrentOperationCount:4];
    });
    return sharedImageProcessingQueue;
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setUp
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageDownloaded:) name:NPRDownloadImageDidSucceedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(progressChanged:) name:NPRImageDownloadProgressChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(imageDownloadFailed:) name:NPRDownloadImageDidFailNotification object:nil];
    
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
    
    [[NPRDiskCache sharedDiskCache] setCacheDirectoryName:@"nprimageviewCache"];
    
    [self setBuiltInTapGestureRecognizerEnabled:YES];
    
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

- (void)setupTapGesture {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)];
    [tapGesture setDelegate:self];
    tapGesture.cancelsTouchesInView = NO;
    [self addGestureRecognizer:tapGesture];
    [self setUserInteractionEnabled:YES];
    self.tapGesture = tapGesture;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    
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

- (NPRDiskCache *)sharedCache {
    return [NPRDiskCache sharedDiskCache];
}

- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString {
    return [[NPRImageOperationQueue sharedQueue] isDownloadingImageAtURLString:urlString];
}

- (BOOL)hasDownloadedOriginalImageAtURL:(NSString *)url {
    return ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:url]);
}

#pragma mark - Setter

- (void)setBuiltInTapGestureRecognizerEnabled:(BOOL)builtInTapGestureRecognizerEnabled {
    _builtInTapGestureRecognizerEnabled = builtInTapGestureRecognizerEnabled;
    if (_builtInTapGestureRecognizerEnabled) {
        if (!self.tapGesture) {
            [self setupTapGesture];
        } else {
            [self addGestureRecognizer:self.tapGesture];
        }
    } else {
        [self removeGestureRecognizer:self.tapGesture];
        self.tapGesture = nil;
    }
}

- (void)setShouldHideProgressView:(BOOL)shouldHideProgressView {
    _shouldHideProgressView = shouldHideProgressView;
    if (_shouldHideProgressView) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NPRImageDownloadProgressChangedNotification object:nil];
        [self.progressView setHidden:YES];
    } else {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(progressChanged:) name:NPRImageDownloadProgressChangedNotification object:nil];
        [self.progressView setHidden:NO];
    }
}

- (void)hideAllLoadingIndicators {
    if (!self.progressView.isHidden) {
        [self.progressView setHidden:YES];
    }
    if (self.indicatorView.isAnimating) {
        [self.indicatorView stopAnimating];
    }
}

- (void)setImage:(UIImage *)image {
    [self willChangeValueForKey:@"image"];
    [super setImage:image];
    [self didChangeValueForKey:@"image"];
    self.imageContentURL = nil;
    [self hideAllLoadingIndicators];
}

- (void)setImage:(UIImage *)image fromURL:(NSURL *)url {
    [self willChangeValueForKey:@"image"];
    [super setImage:image];
    [self didChangeValueForKey:@"image"];
    self.imageContentURL = url;
    [self hideAllLoadingIndicators];
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

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage {
    if (URL && ![URL.absoluteString isEqualToString:self.imageContentURL.absoluteString])
    {
        self.imageContentURL = URL;
        
        [self.messageLabel setText:nil];
        [self.messageLabel setHidden:YES];
        [self.progressView setHidden:YES];
        
        self.placeholderImage = placeholderImage;
        [self showPlaceholderImage];
        if (!self.shouldHideIndicatorView) {
            [self.indicatorView startAnimating];
            [self.indicatorView setHidden:NO];
        }
        
        if (![self loadImageFromDiskOrCacheForURLString:self.imageContentURL.absoluteString]) {
            [self queueImageForProcessingForURLString:URL.absoluteString];
        }
    } else {
        if (![self isDownloadingImageAtURLString:URL.absoluteString]) {
            [self.indicatorView stopAnimating];
        }
        if (!URL) {
            self.image = self.placeholderImage;
            [self.indicatorView stopAnimating];
            [self.progressView setProgress:0];
            [self.progressView setHidden:YES];
        }
    }
}

#pragma mark - Image Processing

- (void)imageDownloadFailed:(NSNotification *)notification {
    NSDictionary *notif = notification.userInfo;
    NSURL *url = [notif objectForKey:NPRImageURLKey];
    
    [[NPRFailDownloadArray array] addObject:url.absoluteString];
    
    if ([url.absoluteString isEqualToString:self.imageContentURL.absoluteString]) {
        if (self.shouldHideErrorMessage) {
            [self.messageLabel setHidden:YES];
        } else {
            [self.messageLabel setText:NSLocalizedString(@"Image cannot be downloaded. Tap to reload.", nil)];
            [self.messageLabel setHidden:NO];
        }
        
        [self.indicatorView stopAnimating];
        [self.progressView setHidden:YES];
        [self setNeedsLayout];
        [self setProcessedImageOnMainThread:@[[NSNull null], url.absoluteString, url.absoluteString]];
    }
}

- (void)imageDownloaded:(NSNotification *)notification {
    NSDictionary *notif = notification.userInfo;
    UIImage *image = [notif objectForKey:NPRDidDownloadImageNotificationImageKey];
    NSURL *url = [notif objectForKey:NPRImageURLKey];
    
    [[NPRFailDownloadArray array] removeObject:url.absoluteString];
    NSString *thisKey = [self cacheKeyWithURL:url.absoluteString];
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        UIImage *im = [self processImage:image key:thisKey urlString:url.absoluteString];
        if (im) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setProcessedImageOnMainThread:@[im,thisKey,url.absoluteString]];
            });
        }
    }];
    
    [[[self class] imageProcessingQueue] addOperation:blockOperation];
}

- (void)progressChanged:(NSNotification *)notification {
    NSDictionary *notif = notification.userInfo;
    NSURL *url = [notif objectForKey:NPRImageURLKey];
    NSString *urlString = url.absoluteString;
    
    if ([urlString isEqualToString:self.imageContentURL.absoluteString]) {
        float totalBytesRead = [notif[NPRImageDownloadProgressChangedNotificationBytesTotalBytesReadKey] floatValue];
        float totalBytesExpectedToRead = [notif[NPRImageDownloadProgressChangedNotificationTotalBytesExpectedKey] floatValue];
        
        if ((float)totalBytesRead/(float)totalBytesExpectedToRead  < 1) {
            [self.messageLabel setText:nil];
            [self.messageLabel setHidden:YES];
            
            if (!self.shouldHideIndicatorView) {
                if (self.indicatorView.isHidden) {
                    [self.indicatorView startAnimating];
                    [self.indicatorView setHidden:NO];
                }
            }
        }
        if (self.progressView.isHidden) {
            if (!self.shouldHideProgressView) {
                [self.progressView setHidden:NO];
                [self setNeedsLayout];
            }
        }
        
        [self.progressView setProgress:(float)totalBytesRead/(float)totalBytesExpectedToRead animated:NO];
        if (totalBytesRead == totalBytesExpectedToRead) {
            [self.progressView setHidden:YES];
        }
    }
}

- (void)showPlaceholderImage {
    [super setImage:self.placeholderImage];
}

- (void)continueImageProcessingFromDiskWithKey:(NSString *)key processingKey:(NSString *)processKey urlString:(NSString *)urlString{
    [self.progressView setHidden:YES];
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        UIImage *image = [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
        if (image) {
            UIImage *im = [self processImage:image key:processKey urlString:urlString];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setProcessedImageOnMainThread:@[im, processKey, urlString]];
            });
            
        }
    }];
    
    [[[self class] imageProcessingQueue] addOperation:blockOperation];
}

- (BOOL)loadImageFromDiskOrCacheForURLString:(NSString *)url {
    // check if image exists in cache
    NSString *key = [self cacheKeyWithURL:url];
    UIImage *processedImage = [self cachedProcessImageForKey:key];
    if (processedImage) {
        [self setImage:processedImage fromURL:[NSURL URLWithString:url]];
        return YES;
    } else {
        // check if processed image exists on disk
        if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:key]) {
            [self continueImageProcessingFromDiskWithKey:key
                                           processingKey:key urlString:url];
            return YES;
        }
        // check if original image exists on disk
        else {
            if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:url]) {
                [self continueImageProcessingFromDiskWithKey:url
                                               processingKey:key urlString:url];
                return YES;
            }
        }
    }
    return NO;
}

- (void)queueImageForProcessingForURLString:(NSString *)url {
    // image cannot be found on disk nor cache. Let's download it.
    
    [[NPRImageOperationQueue sharedQueue] queueImageURLString:url withProcessingBlock:^UIImage *(UIImage *image) {
        return image;
    } progress:^void(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        // handled when notification received
    } success:^void(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        // handled when notification received
    } failure:^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        // handled when notification received
    }];
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
    NSString *currentImageURLString = self.imageContentURL.absoluteString;
    UIImage *processedImage = [array objectAtIndex:0];
    processedImage = ([processedImage isKindOfClass:[NSNull class]])? nil: processedImage;
    
    //set image
    if ([currentImageURLString isEqualToString:[array objectAtIndex:2]])
    {
        
        // crossfade
        if (self.crossFade) {
            id animation = objc_msgSend(NSClassFromString(@"CATransition"), @selector(animation));
            objc_msgSend(animation, @selector(setType:), @"kCATransitionFade");
            objc_msgSend(self.layer, @selector(addAnimation:forKey:), animation, nil);
        }
        
        //set processed image
        [self setImage:processedImage fromURL:[NSURL URLWithString:array[2]]];
        
        if (processedImage) {
            [self.messageLabel setHidden:YES];
        } else {
            if (self.shouldHideErrorMessage) {
                [self.messageLabel setHidden:YES];
            } else {
                [self.messageLabel setHidden:NO];
            }
            
        }
        [self.progressView setHidden:YES];
        [self.indicatorView stopAnimating];
    }
}

#pragma mark - Operations stuff

+ (void)printOperations {
    for (AFImageRequestOperation *operation in [NPRImageOperationQueue sharedQueue].operations) {
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
    [[NPRImageOperationQueue sharedQueue] cancelAllOperations];
}


#pragma mark - Cache

- (NSString *)cacheKeyWithURL:(NSString *)url {
    return [NSString stringWithFormat:@"%@_%@_%i", url, NSStringFromCGSize(self.bounds.size) ,self.contentMode];
}

- (UIImage *)cachedProcessImageForKey:(NSString *)key {
    return [[[self class] processedImageCache] objectForKey:key];
}

- (void)cacheProcessedImage:(UIImage *)processedImage forKey:(NSString *)cacheKey {
    [[[self class] processedImageCache] setObject:processedImage forKey:cacheKey];
    [[NPRDiskCache sharedDiskCache] writeImageToDisk:processedImage key:cacheKey];
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
        NSOperationQueue *sharedQueue = [NPRImageOperationQueue sharedQueue];
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
    [[NPRImageOperationQueue sharedQueue] removeObserver:self forKeyPath:@"operationCount"];
}

@end