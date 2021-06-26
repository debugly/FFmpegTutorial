//
// MRRWeakProxy.m
// FFmpegTutorial-iOS
//
//  Created by qianlongxu on 04/18/2020.
//  Copyright (c) 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRRWeakProxy.h"

@implementation MRRWeakProxy

#if ! __has_feature(objc_arc)
- (void)dealloc
{
    self.target = nil;
}
#endif

- (instancetype)initWithTarget:(id)target
{
    self.target = target;
    return self;
}

+ (instancetype)weakProxyWithTarget:(id)target
{
#if __has_feature(objc_arc)
    return [[self alloc]initWithTarget:target];
#else
    return [[[self alloc]initWithTarget:target]autorelease];
#endif
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (Class)superclass {
    return [_target superclass];
}

- (Class)class {
    return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}

- (BOOL)isProxy {
    return YES;
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}

@end

