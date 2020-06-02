//
//  MRThread.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRThread : NSObject

///在任务开始前指定线程的名字
@property (atomic, copy) NSString *name;
///默认情况下，等待join，如果不想拥有此特性，可以在执行前将 joinModeName 置空！！
@property (atomic, copy) NSString *joinModeName;

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument;

- (void)start;
/**
 如果已经完成或者禁用了join，则立马返回NO；
 否则阻塞等待，直到当前线程执行完毕才返回YES；
 */
- (BOOL)join;
- (void)cancel;
- (BOOL)isFinished;

@end

NS_ASSUME_NONNULL_END
