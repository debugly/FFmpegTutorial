//
//  FFAudioFrameQueue.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFFrameQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFAudioFrameQueue : FFFrameQueue

- (void)enQueue:(AVFrame *)frame;
- (double)clock;
//sync and wait
- (int)fillBuffers:(uint8_t * _Nonnull [_Nullable 2])buffer
          byteSize:(int)bufferSize;

@end

NS_ASSUME_NONNULL_END
