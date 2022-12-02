//
//  MRMetalOffscreenRendering.h
//  FFmpegTutorial-macOS
//
//  Created by Reach Matt on 2022/12/2.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
@class MTLRenderPassDescriptor;
@import CoreGraphics;

@interface MRMetalOffscreenRendering : NSObject

- (BOOL)canReuse:(CGSize)size;

- (MTLRenderPassDescriptor *)offscreenRender:(CGSize)size
                                      device:(id<MTLDevice>)device;

- (CGImageRef)snapshot;

@end

NS_ASSUME_NONNULL_END
