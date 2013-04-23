//
//  ImageViewCell.m
//  ImageViewProgressActivity
//
//  Created by Nico Prananta on 4/22/13.
//  Copyright (c) 2013 Touches. All rights reserved.
//

#import "ImageViewCell.h"

#import "NPRImageView.h"

#import <QuartzCore/QuartzCore.h>

@interface ImageViewCell ()
@end

@implementation ImageViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _nprImageView = [[NPRImageView alloc] initWithFrame:CGRectInset(self.contentView.bounds, 10, 10)];
        [_nprImageView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_nprImageView setBackgroundColor:[UIColor whiteColor]];
        [_nprImageView setContentMode:UIViewContentModeScaleAspectFill];
        [self.contentView addSubview:_nprImageView];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self.nprImageView.layer setShadowColor:[UIColor darkGrayColor].CGColor];
    [self.nprImageView.layer setShadowOffset:CGSizeMake(2, 2)];
    [self.nprImageView.layer setShadowOpacity:0.6];
    [self.nprImageView.layer setShadowPath:[UIBezierPath bezierPathWithRect:_nprImageView.bounds].CGPath];
    [self.nprImageView.layer setShadowRadius:1];
    
}

- (void)setImageURL:(NSURL *)imageURL placeholderImage:(UIImage *)placeholderImage{
    [self.nprImageView setImageWithContentsOfURL:imageURL placeholderImage:placeholderImage];
}

@end
