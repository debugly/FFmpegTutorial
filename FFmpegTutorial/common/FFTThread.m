//
//  FFTThread.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//
//
// [self performSelector:@selector(bye) onThread:self.thread withObject:nil waitUntilDone:YES]; -> _pthread_cond_wait ; cause dead lock！



#import "FFTThread.h"

#define PRINT_THREAD_LOG_ON 1

#if PRINT_THREAD_LOG_ON

#define PRINT_THREAD_DEBUG(_msg_) \
do{ \
NSLog(@"[t] [%@] %@",self.name,_msg_); \
}while(0)

#else

#define PRINT_THREAD_DEBUG(_msg_) \
do{ \
}while(0)

#endif

@interface FFTThread ()

@property (nonatomic, weak) id threadTarget;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) SEL threadSelector;//实际调度任务
@property (nonatomic, strong) id threadArgs;
@property (nonatomic, copy) void(^workBlock)(void);
@property (nonatomic, strong) NSCondition *condition;

@end

@implementation FFTThread

- (void)dealloc
{
    PRINT_THREAD_DEBUG(@"dealloc");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.condition = [NSCondition new];
        self.thread = [[NSThread alloc] initWithTarget:self selector:@selector(workFunc) object:nil];
    }
    return self;
}

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument
{
    self = [self init];
    if (self) {
        self.threadTarget = target;
        self.threadSelector = selector;
        self.threadArgs = argument;
    }
    return self;
}

- (instancetype)initWithBlock:(void (^)(void))block
{
    self = [self init];
    if (self) {
        self.workBlock = block;
    }
    return self;
}

- (void)setName:(NSString *)name
{
    [self.thread setName:name];
}

- (NSString *)name
{
    return self.thread.name;
}

- (void)workFunc
{
    //取消了就直接返回，不再处理
    if ([self isCanceled]) {
        return;
    }
    
    // iOS 子线程需要显式创建 autoreleasepool 以释放 autorelease 对象
    @autoreleasepool {
        if ([self.threadTarget respondsToSelector:self.threadSelector]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self.threadTarget performSelector:self.threadSelector withObject:self.threadArgs];
            #pragma clang diagnostic pop
        }
        
        if (self.workBlock) {
            self.workBlock();
        }
        PRINT_THREAD_DEBUG(@"signal.");
        [self.condition signal];
    }
}

- (void)start
{
    [self.thread start];
}

- (void)join
{
    while (![self.thread isFinished] && [self.thread isExecuting]) {
        PRINT_THREAD_DEBUG(@"wait.");
        BOOL ok = [self.condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        if (ok) {
            PRINT_THREAD_DEBUG(@"break wait.");
            break;
        }
    }
    PRINT_THREAD_DEBUG(@"joined.");
}

- (void)cancel
{
    if (![self.thread isCancelled]) {
        [self.thread cancel];
    }
}

- (BOOL)isCanceled
{
    return [self.thread isCancelled];
}

- (BOOL)isFinished
{
    return [self.thread isFinished];
}

@end
