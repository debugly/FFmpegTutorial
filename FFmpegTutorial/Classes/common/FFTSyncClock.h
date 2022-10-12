//
//  FFTSyncClock.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/8/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTSyncClock : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double pts;
@property (atomic, assign) BOOL eof;

- (void)setClock:(double)pts;
- (double)getClock;

@end

NS_ASSUME_NONNULL_END
