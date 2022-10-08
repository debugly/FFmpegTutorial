//
// MRRWeakProxy.h
// FFmpegTutorial-iOS
//
//  Created by qianlongxu on 04/18/2020.
//  Copyright (c) 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 傀儡代理，防止持有target；内部做消息转发；常结合NSTimer或者自身持有 self 时可以用此傀儡！

//objc[93999]: Class MRRWeakProxy is implemented in both /System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/MediaRemote (0x7fff8c6f70e0) and /Users/qianlongxu/Library/Developer/Xcode/DerivedData/SHVideoPlayer-ekukzgngxlhxhkctzkktpedajyya/Build/Products/Debug/SHPlayer.app/Contents/Frameworks/MRFoundation.framework/Versions/A/MRFoundation (0x1006d52f0). One of the two will be used. Which one is undefined.

#import <Foundation/Foundation.h>

@interface MRRWeakProxy : NSProxy

#if __has_feature(objc_arc)
@property (nonatomic, weak) id target;
#else
@property (nonatomic, assign) id target;
#endif

- (instancetype)initWithTarget:(id)target;

+ (instancetype)weakProxyWithTarget:(id)target;

@end
