//
//  FFTPlatform.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/9/8.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef NSView UIView;
typedef NSColor UIColor;
typedef NSFont UIFont;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface FFTPlatform : NSObject

@end

NS_ASSUME_NONNULL_END
