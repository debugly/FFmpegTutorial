//
//  IJKMetalOffscreenRendering.h
//  FFmpegTutorial-macOS
//
//  Created by Reach Matt on 2022/12/2.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice,MTLCommandBuffer,MTLRenderCommandEncoder;
@import CoreGraphics;

NS_CLASS_AVAILABLE(10_13, 11_0)
@interface IJKMetalOffscreenRendering : NSObject

- (CGImageRef)snapshot:(CGSize)targetSize
                device:(id <MTLDevice>)device
         commandBuffer:(id<MTLCommandBuffer>)commandBuffer
       doUploadPicture:(void(^)(id<MTLRenderCommandEncoder>))block;

@end

NS_ASSUME_NONNULL_END
