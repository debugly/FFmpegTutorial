//
//  MRThread.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import <Foundation/Foundation.h>

@interface MRThread : NSObject

///在任务开始前指定线程的名字
@property (atomic, copy) NSString *name;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument;
- (instancetype)initWithBlock:(void(^)(void))block;
- (void)start;
/**
 如果已经完成或者禁用了join，则立马返回NO；
 否则阻塞等待，直到当前线程执行完毕才返回YES；
 */
- (BOOL)join;
/**
 明确不需要join，不关心线程任务何时执行完毕
 */
- (void)notJoin;
/**
 告知内部线程，外部期望取消
 */
- (void)cancel;
- (BOOL)isCanceled;
- (BOOL)isFinished;

@end
