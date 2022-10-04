//
//  MR0x12VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/9.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x12VideoRenderer.h"

@implementation MR0x12VideoRenderer

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setWantsLayer:YES];
    self.layer.backgroundColor = [[NSColor blackColor] CGColor];
}

@end
