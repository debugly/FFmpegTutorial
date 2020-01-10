//
//  MRVideoFrame.h
//  FFmpeg006-1
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>
#import <CoreImage/CIImage.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface MRVideoFrame : NSObject

@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) CIImage *ciImage;
@property (assign, nonatomic) float duration;
@property (assign, nonatomic) BOOL eof;
@property (assign, nonatomic) CMSampleBufferRef sampleBuffer;

@end
