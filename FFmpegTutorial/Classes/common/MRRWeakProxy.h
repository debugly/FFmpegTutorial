//
//  MRRWeakProxy.h
//  FFmpegTutorial

//  Created by qianlongxu on 16/3/9.
//
// 傀儡代理，防止持有target；内部做消息转发；常结合NSTimer，NSThread 等持有 target 时可以用此傀儡！

//objc[93999]: Class MRWeakProxy is implemented in both /System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/MediaRemote (0x7fff8c6f70e0) and /Users/qianlongxu/Library/Developer/Xcode/DerivedData/SHVideoPlayer-ekukzgngxlhxhkctzkktpedajyya/Build/Products/Debug/SHPlayer.app/Contents/Frameworks/MRFoundation.framework/Versions/A/MRFoundation (0x1006d52f0). One of the two will be used. Which one is undefined.

#import <Foundation/Foundation.h>

#if ! __has_feature(objc_arc)
#error "ARC Only"
#endif

@interface MRRWeakProxy : NSProxy

@property (nonatomic, weak) id target;

- (instancetype)initWithTarget:(id)target;

+ (instancetype)weakProxyWithTarget:(id)target;

@end
