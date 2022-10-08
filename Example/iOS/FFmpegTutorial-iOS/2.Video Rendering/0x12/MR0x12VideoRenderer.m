//
//  MR0x12VideoRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2022/9/11.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x12VideoRenderer.h"

@interface MR0x12VideoRenderer()

@property (nonatomic, strong) UIImageView *renderer;

@end

@implementation MR0x12VideoRenderer

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self.renderer = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:self.renderer];
        self.renderer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.renderer = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:self.renderer];
        self.renderer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)dispalyUIImage:(UIImage *)img
{
    self.renderer.image = img;
}

@end
