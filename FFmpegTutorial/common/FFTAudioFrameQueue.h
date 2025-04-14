//
//  FFTAudioFrameQueue.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFTFrameQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTAudioFrameQueue : FFTFrameQueue

- (void)enQueue:(AVFrame *)frame;
- (double)clock;
//sync and wait
- (int)fillBuffers:(uint8_t * _Nonnull [_Nullable 2])buffer
          byteSize:(int)bufferSize;

@end

NS_ASSUME_NONNULL_END
