//
//  FFTFrameQueue.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef struct AVFrame AVFrame;

@interface FFFrameItem : NSObject

@property (nonatomic, assign) AVFrame *frame;
@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double duration; //frame duration

- (instancetype)initWithAVFrame:(AVFrame *)frame;

@end

@interface FFTFrameQueue : NSObject

@property (nonatomic, assign) BOOL eof;

- (void)push:(FFFrameItem *)frame;
- (void)pop;
- (int)count;
- (FFFrameItem *)peekLast;
- (FFFrameItem *)peek;
- (FFFrameItem *)peekNext;
- (void)cancel;
- (BOOL)isCanceled;

@end

NS_ASSUME_NONNULL_END
