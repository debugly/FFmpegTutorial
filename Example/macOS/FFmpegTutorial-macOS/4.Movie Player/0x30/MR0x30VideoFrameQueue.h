//
//  MR0x30VideoFrameQueue.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/16.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef struct AVFrame AVFrame;
@interface MR0x30VideoFrameQueue : NSObject

- (void)enQueue:(AVFrame *)frame;
- (NSUInteger)size;
//move ref to dst;wait forever
- (void)syncDeQueue:(AVFrame *)dst;
//move ref to dst;not wait;return YES means got frame.
- (void)asyncDeQueue:(void(^)(AVFrame * _Nullable frame))block;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
