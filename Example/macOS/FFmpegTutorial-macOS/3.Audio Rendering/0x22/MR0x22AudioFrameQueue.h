//
//  MR0x22AudioFrameQueue.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct AVFrame AVFrame;
@interface MR0x22AudioFrameQueue : NSObject

- (void)enQueue:(AVFrame *)frame;
- (NSUInteger)size;
//sync and wait
- (void)fillBuffers:(uint8_t *[2])buffer
           byteSize:(int)bufferSize;

- (void)cancel;

@end
