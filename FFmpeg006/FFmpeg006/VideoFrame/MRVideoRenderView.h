//
//  MRVideoRenderView.h
//  FFmpeg006
//
//  Created by Matt Reach on 2019/1/28.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRVideoRenderView : UIView

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;

@end

NS_ASSUME_NONNULL_END
