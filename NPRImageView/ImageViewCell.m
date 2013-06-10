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
        
        _customTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_customTextLabel setBackgroundColor:[UIColor clearColor]];
        [_customTextLabel setFont:[UIFont boldSystemFontOfSize:25]];
        [_customTextLabel setNumberOfLines:0];
        [_customTextLabel setTextColor:[UIColor whiteColor]];
        [_customTextLabel.layer setShadowColor:[UIColor darkGrayColor].CGColor];
        [_customTextLabel.layer setShadowOffset:CGSizeMake(2, 2)];
        [_customTextLabel.layer setShadowOpacity:0.6];
        [_customTextLabel.layer setShadowRadius:1];
        
        [self.contentView addSubview:_nprImageView];
        [self.contentView addSubview:_customTextLabel];
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
    
    CGFloat margin = 20;
    CGRect frame = self.customTextLabel.frame;
    frame.size.width = CGRectGetWidth(self.nprImageView.frame) - 2 * margin;
    frame.origin.x = margin;
    frame.origin.y = margin;
    self.customTextLabel.frame = frame;
    [self.customTextLabel sizeToFit];    
}

- (void)setImageURL:(NSURL *)imageURL placeholderImage:(UIImage *)placeholderImage{
    [self.nprImageView setImageWithContentsOfURL:imageURL placeholderImage:placeholderImage];
}

@end
