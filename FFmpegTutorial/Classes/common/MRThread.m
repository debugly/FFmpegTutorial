//
//  MRThread.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import "MRThread.h"
#import "MRRWeakProxy.h"

@interface MRThread ()

@property (nonatomic, weak) MRRWeakProxy *threadTarget;

@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) SEL threadSelector;//实际调度任务
@property (nonatomic, strong) id threadArgs;

@end

@implementation MRThread

- (void)dealloc
{
    NSLog(@"%@ dealloc",self.name);
}

- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(nullable id)argument
{
    self = [super init];
    if (self) {
        
        self.threadTarget = target;
        self.threadSelector = selector;
        self.threadArgs = argument;
        self.joinModeName = @"joinme";
        ///避免NSThread和self相互持有，外部释放self时，NSThread延长self的生命周期，带来副作用！
        MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
        ///不允许重复准备
        self.thread = [[NSThread alloc] initWithTarget:weakProxy selector:@selector(workFunc) object:nil];
    }
    
    return self;
}

- (void)workFunc
{
    ///取消了就直接返回，不再处理
    if ([[NSThread currentThread] isCancelled]) {
        return;
    }
    
    /// iOS 子线程需要显式创建 autoreleasepool 以释放 autorelease 对象
    @autoreleasepool {
        
        [[NSThread currentThread] setName:self.name];
        
        ///嵌套的这个自动释放池也是必要的！！防止在 threadSelector 里完成任务后，将线程释放，但是却进入了死等的Runloop逻辑中，由于外层的 @autoreleasepool 不能回收相关内存，最终导致整个线程得不到释放。[可以将FFPlayer0x02 _stop 方法中的join注释掉观察] 
        @autoreleasepool {
            if ([self.threadTarget respondsToSelector:self.threadSelector]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self.threadTarget performSelector:self.threadSelector withObject:self.threadArgs];
                #pragma clang diagnostic pop
            } else {
                NSAssert(NO, @"WTF?? %@ can't responds the selector:%@",NSStringFromClass([self.threadTarget class]),NSStringFromSelector(self.threadSelector));
            }
        }
        
        if (self.joinModeName.length > 0) {
            ///增加一个 port，让 RunLoop run 起来
            [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:self.joinModeName];
            [[NSRunLoop currentRunLoop] runMode:self.joinModeName beforeDate:[NSDate distantFuture]];
            
            NSLog(@"%@ joined!",[[NSThread currentThread] name]);
        }
    }
}

- (void)bye
{
    NSLog(@"bye:%@",self.name);
}

- (void)start
{
    [self.thread start];
}

- (BOOL)join
{
    if (![self.thread isFinished] && self.joinModeName.length > 0) {
//        for (;![self.thread isFinished];) {
//            mr_usleep(2);
//        }
//        [self bye];
        [self performSelector:@selector(bye) onThread:self.thread withObject:nil waitUntilDone:YES modes:@[self.joinModeName]];
        return YES;
    }
    return NO;
}

- (void)cancel
{
    if (![self.thread isCancelled]) {
        [self.thread cancel];
    }
}

- (BOOL)isFinished
{
    return [self.thread isFinished];
}

@end
