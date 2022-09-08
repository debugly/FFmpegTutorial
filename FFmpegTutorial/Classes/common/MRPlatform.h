//
//  MRPlatform.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/9/8.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef UIView NSView
typedef UIColor NSColor
typedef UIFont NSFont
#else

#endif

NS_ASSUME_NONNULL_BEGIN

@interface MRPlatform : NSObject

@end

NS_ASSUME_NONNULL_END
