//
//  MR0x34AudioFrameQueue.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/25.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct AVFrame AVFrame;
@interface MR0x34AudioFrameQueue : NSObject

@property (nonatomic,assign,readonly) int64_t position;

- (void)enQueue:(AVFrame *)frame;
- (NSUInteger)size;
//sync and wait
- (int)fillBuffers:(uint8_t *[2])buffer
          byteSize:(int)bufferSize;

- (void)cancel;

@end
