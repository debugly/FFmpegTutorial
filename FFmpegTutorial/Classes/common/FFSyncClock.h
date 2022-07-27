//
//  FFSyncClock.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFSyncClock : NSObject

@property (nonatomic, assign) double pts;
@property (nonatomic, assign) double pts_drift;
@property (nonatomic, assign) double last_update;
@property (nonatomic, assign) double frame_timer;
//每个采样几个字节
@property (nonatomic, assign) int bytesPerSample;
@property (atomic, assign) BOOL eof;

- (void)setClock:(double)pts;
- (double)getClock;

@end

NS_ASSUME_NONNULL_END
