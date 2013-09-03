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

#import "NPROperationQueueObserver.h"
#import "NPRFailDownloadArray.h"

#import <objc/message.h>

NSString * const NPRDidSetImageNotification = @"nicnocquee.NPRImageView.didSetImage";

@interface NPRImageView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIImageView *customImageView;

@end


#pragma mark - NPRImageView

@implementation NPRImageView

+ (NPROperationQueue *)processingQueue {
    return [NPROperationQueue processingQueue];
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
    
    [[NPROperationQueueObserver sharedQueueObserver] observe];
    
    [[NPRDiskCache sharedDiskCache] setCacheDirectoryName:@"nprimageviewCache"];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageViewTapped:)];
    [tapGesture setDelegate:self];
    tapGesture.cancelsTouchesInView = NO;
    [_customImageView setOpaque:NO];
    [_customImageView setUserInteractionEnabled:YES];
    [self addGestureRecognizer:tapGesture];
    [self setUserInteractionEnabled:YES];
    
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

#pragma mark - Setter

- (void)setImage:(UIImage *)image {
    self.customImageView.image = image;
    if (image) {
        [self.indicatorView stopAnimating];
    }
}

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage {
    if (![URL.absoluteString isEqualToString:self.imageContentURL.absoluteString])
    {
        [self.messageLabel setText:nil];
        [self.messageLabel setHidden:YES];
        [self.progressView setHidden:YES];
        [self setNeedsLayout];
        
        self.imageContentURL = URL;
        
        self.placeholderImage = placeholderImage;
        
        [self queueImageForProcessingForURLString:URL.absoluteString];
    } else {
        if (![[NPROperationQueue processingQueue] isDownloadingImageAtURLString:URL.absoluteString]) {
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

- (void)showPlaceholderImage {
    self.customImageView.image = self.placeholderImage;
}


#pragma mark - Image Processing

- (void)queueImageForProcessingForURLString:(NSString *)url {
    // check if image exists in cache
    NSString *key = [self cacheKeyWithURL:url];
    UIImage *processedImage = [self cachedProcessImageForKey:key];
    if (processedImage) {
        [self setImage:processedImage];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter postNotificationName:NPRDidSetImageNotification object:self];
        });
        return;
    } else {
        // check if processed image or original image exists on disk
        if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:key]) { // can be original or processed because cacheKeyWithURL can return url itself if useOriginal is set to YES
            [self continueImageProcessingFromDiskWithKey:key urlString:url];
            return;
        } else if ([[NPRDiskCache sharedDiskCache] imageExistsOnDiskWithKey:url]) { // original
            [self continueImageProcessingFromDiskWithKey:url urlString:url];
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
    
    NSURL *urlToDownload = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlToDownload];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    AFImageRequestOperation *imageOperation = [AFImageRequestOperation imageRequestOperationWithRequest:request imageProcessingBlock:^UIImage *(UIImage *image) {
        [[NPRDiskCache sharedDiskCache] writeImageToDisk:image key:url]; // cache original image
        return [self processImage:image key:key urlString:url];
    } success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        [[NPRFailDownloadArray array] removeObject:request.URL.absoluteString];
        [[NPROperationQueue processingQueue] imageDownloadedAtURL:request.URL.absoluteString];
        NSString *thisKey = [self cacheKeyWithURL:request.URL.absoluteString];
        [self setProcessedImageOnMainThread:@[image,thisKey,request.URL.absoluteString]];
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        [[NPRFailDownloadArray array] addObject:request.URL.absoluteString];
        [[NPROperationQueue processingQueue] imageDownloadedAtURL:request.URL.absoluteString];
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
    
    [[NPROperationQueue processingQueue] queueProcessingOperation:imageOperation urlString:url];
}

- (void)continueImageProcessingFromDiskWithKey:(NSString *)key urlString:(NSString *)urlString{
    if (!self.shouldHideIndicatorView) {
        [self.indicatorView startAnimating];
        [self.indicatorView setHidden:NO];
    }
    
    [self showPlaceholderImage];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        UIImage *image = [[NPRDiskCache sharedDiskCache] imageFromDiskWithKey:key];
        if (image) {
            UIImage *im = [self processImage:image key:key urlString:urlString];
            NSString *newKey = key;
            if ([key isEqualToString:urlString]) {
                newKey = [self cacheKeyWithURL:urlString];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setProcessedImageOnMainThread:@[im, newKey, urlString]];
            });
        }
    });
}

- (UIImage *)processImage:(UIImage *)image key:(NSString *)key urlString:(NSString *)url{
    //check cache
    UIImage *processedImage = (url)?[self cachedProcessImageForKey:key]:nil;
    if (!processedImage)
    {
        if (image) {
            if (!self.useOriginal) {
                //crop and scale image
                processedImage = [image imageCroppedAndScaledToSize:self.bounds.size
                                                        contentMode:self.contentMode
                                                           padToFit:NO];
            } else {
                processedImage = image;
            }
        } else {
            processedImage = self.placeholderImage;
        }
    }
    
    if (processedImage)
    {
        //cache image
        [self cacheProcessedImage:processedImage forKey:key url:url];
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
        [self setImage:processedImage];
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

- (NSString *)cacheKeyWithURL:(NSString *)url {
    if (self.useOriginal) {
        return url;
    }
    return [NSString stringWithFormat:@"%@_%@_%i",
            url,
            NSStringFromCGSize(self.bounds.size),
            self.contentMode];
}

- (UIImage *)cachedProcessImageForKey:(NSString *)key {
    return [[[self class] processedImageCache] objectForKey:key];
}

- (void)cacheProcessedImage:(UIImage *)processedImage forKey:(NSString *)cacheKey  url:url {
    [[[self class] processedImageCache] setObject:processedImage forKey:cacheKey];
    if (![cacheKey isEqualToString:url]) {
        [[NPRDiskCache sharedDiskCache] writeImageToDisk:processedImage key:cacheKey]; // processed and original is the same, no need to cache to disk again.
    }
}

@end
