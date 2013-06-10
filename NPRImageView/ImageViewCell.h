//
//  ImageViewCell.h
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NPRImageView;

@interface ImageViewCell : UITableViewCell

@property (nonatomic, strong) NPRImageView *nprImageView;
@property (nonatomic, strong) UILabel *customTextLabel;

- (void)setImageURL:(NSURL *)imageURL placeholderImage:(UIImage *)placeholderImage;

@end
