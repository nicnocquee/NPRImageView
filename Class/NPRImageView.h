//
//  NPImageView.h
//  NPRImageView
//
//  Created by Nico Prananta on 4/23/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NPRImageView : UIImageView

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIImage *placeholderImage;

@property (nonatomic, assign) BOOL shouldHideIndicatorView;

- (void)setImageWithContentsOfURL:(NSURL *)URL placeholderImage:(UIImage *)placeholderImage;

+ (UIImage *)originalImageForKey:(NSString *)key;

@end
