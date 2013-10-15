//
//  NPImageView.h
//  https://github.com/nicnocquee/NPRImageView
//
//  Created by Nico Prananta (@nicnocquee) on 4/23/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NPRImageView;
@class NPRDiskCache;

extern NSString * const NPRDidSetImageNotification;

@interface NPRImageView : UIImageView

/// A Boolean that determines whether cross fade animation when setting image is performed.
@property (nonatomic, assign) BOOL crossFade;

/// Progress view that shows the progress of image download. Set your own progress view to customize. Set shouldHideProgressView to YES to hide the progressView.
/// @see shouldHideProgressView, indicatorView, messageLabel
@property (nonatomic, strong) UIProgressView *progressView;

/// Activity indicator view that indicates the image download is in progress. Set your own activity view to customize.
/// @see shouldHideIndicatorView, progressView, messageLabel
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

/// Label that appears when image download fails.
/// @see shouldHideErrorMessage, progressView, indicatorView
@property (nonatomic, strong) UILabel *messageLabel;

/// Placeholder image that will be shown while the requested image is being downloaded. Default is nil.
@property (nonatomic, strong) UIImage *placeholderImage;

/// The URL of the image to download.
@property (nonatomic, copy) NSURL *imageContentURL;

/// The disk cache used by NPRImageView
@property (nonatomic, readonly) NPRDiskCache *sharedCache;

/// A Boolean that determines whether indicator view should be hidden. Default is NO.
@property (nonatomic, assign) BOOL shouldHideIndicatorView;

/// A Boolean that determines whether progress view should be hidden. Default is NO.
@property (nonatomic, assign) BOOL shouldHideProgressView;

/// A Boolean that determines whether error message label should be hidden. Default is NO.
@property (nonatomic, assign) BOOL shouldHideErrorMessage;

/// A Boolean that determines whether built in tap gesture recognizer should be enabled. Default is YES. When built in tap gesture is enabled, single tap on image will perform the image download once again when the previous attempt fails. Set this to NO to add your own gesture recognizer.
@property (nonatomic, assign) BOOL builtInTapGestureRecognizerEnabled;

/**
 This is the method that should be called to load the image from URL.
 
 @param URL The URL of the image.
 @param placeholderImage An image to show while download is in progress. Set nil to show nothing.
 */
- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage;

/**
 Returns whether image at URL string is being downloaded.
 
 @param urlString The URL string of the image.
 @return YES if image is being downloaded.
 */
- (BOOL)isDownloadingImageAtURLString:(NSString *)urlString;

/**
 Returns whether original image at URL string has been downloaded.
 
 @param url The URL string of the original image.
 @return YES if image has been downloaded.
 */
- (BOOL)hasDownloadedOriginalImageAtURL:(NSString *)url;

/**
 Cancel all image downloads.
 
 */
+ (void)cancelAllOperations;

@end
