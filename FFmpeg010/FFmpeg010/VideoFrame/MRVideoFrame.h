//
//  MRVideoFrame.h
//  FFmpeg010
//
//  Created by Matt Reach on 2019/3/2.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavutil/frame.h>
#import <UIKit/UIImage.h>
#import <CoreImage/CIImage.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface MRVideoFrame : NSObject

@property (assign, nonatomic) AVFrame *video_frame;
@property (strong, nonatomic) UIImage *image;
@property (strong, nonatomic) CIImage *ciImage;
//当前帧的持续时间
@property (assign, nonatomic) float duration;
@property (assign, nonatomic) BOOL eof;
@property (assign, nonatomic) CMSampleBufferRef sampleBuffer;

@end

#define MR_NUM_DATA_POINTERS 4

typedef struct MRPicture {
    uint8_t *data[MR_NUM_DATA_POINTERS];    ///< pointers to the image data planes
    int linesize[MR_NUM_DATA_POINTERS];     ///< number of bytes per line
} MRPicture;
