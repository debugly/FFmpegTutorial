//
//  FFTThread.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFTThread : NSObject

///在任务开始前指定线程的名字
@property (copy, nullable) NSString * name;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument;
- (instancetype)initWithBlock:(void(^)(void))block;
- (void)start;
/**
 阻塞等待，直到当前线程执行完毕
 */
- (void)join;
/**
 告知内部线程，外部期望取消
 */
- (void)cancel;
- (BOOL)isCanceled;
- (BOOL)isFinished;

@end

NS_ASSUME_NONNULL_END
