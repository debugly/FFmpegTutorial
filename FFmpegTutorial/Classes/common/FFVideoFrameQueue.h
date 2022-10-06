//
//  FFVideoFrameQueue.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFFrameQueue.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFVideoFrameQueue : FFFrameQueue

@property (nonatomic, assign) double streamTimeBase;
//根据 fps 计算得出
@property (nonatomic, assign) double averageDuration;

- (void)enQueue:(AVFrame *)frame;
- (double)clock;

@end

NS_ASSUME_NONNULL_END
