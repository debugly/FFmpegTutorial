//
//  MRThread.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import "MRThread.h"

@interface MRThread ()

@property (nonatomic, weak) id threadTarget;
@property (nonatomic, strong) NSThread *thread;
@property (nonatomic, assign) SEL threadSelector;//实际调度任务
@property (nonatomic, strong) id threadArgs;
@property (nonatomic, copy) void(^workBlock)(void);
@property (nonatomic, strong) NSRunLoop *currentRunloop;
@property (nonatomic, strong) NSPort *runloopPort;

@end

@implementation MRThread

- (void)dealloc
{
    //NSLog(@"%@ thread dealloc",self.name);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.runloopPort = [NSPort port];
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

- (void)workFunc
{
    //取消了就直接返回，不再处理
    if ([self isCanceled]) {
        return;
    }
    
    // iOS 子线程需要显式创建 autoreleasepool 以释放 autorelease 对象
    @autoreleasepool {
        
        [[NSThread currentThread] setName:self.name];
        
        //嵌套的这个自动释放池也是必要的！！防止在 threadSelector 里完成任务后，将线程释放，但是却进入了死等的Runloop逻辑中，由于外层的 @autoreleasepool 不能回收相关内存，最终导致整个线程得不到释放。[可以将FFPlayer0x02 _stop 方法中的join注释掉观察]
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
        }
        
        //线程即使已经取消仍旧使用runloop等待join；除非明确不需要等待
        while (self.runloopPort) {
            //NSLog(@"%@ will runUntilDate!",[[NSThread currentThread] name]);
            if (!self.currentRunloop) {
                self.currentRunloop = [NSRunLoop currentRunLoop];
                //增加一个 port，让 RunLoop run 起来
                [self.currentRunloop addPort:self.runloopPort forMode:NSDefaultRunLoopMode];
            }
           
            [self.currentRunloop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            
            //NSLog(@"%@ after runUntilDate!",[[NSThread currentThread] name]);
        }
    }
}

- (void)bye
{
    //NSLog(@"bye:%@",self.name);
    [self notJoin];
}

- (void)start
{
    [self.thread start];
}

- (BOOL)join
{
    if ([self.thread isExecuting] && ![self.thread isFinished]) {
        if ([NSThread currentThread] == self.thread) {
            [self notJoin];
            return YES;
        } else {
            [self performSelector:@selector(bye) onThread:self.thread withObject:nil waitUntilDone:YES];
            return YES;
        }
    }
    return NO;
}

- (void)notJoin
{
    if (self.runloopPort) {
        [self.runloopPort removeFromRunLoop:self.currentRunloop forMode:NSDefaultRunLoopMode];
        self.runloopPort = nil;
    }
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
