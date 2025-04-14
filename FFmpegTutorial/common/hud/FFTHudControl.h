// FFTHudControl.h
// FFmpegTutorial
//
// Created by Matt Reach on 2022/4/6.

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
typedef NSView UIView;
#else
#import <UIKit/UIKit.h>
#endif

@interface FFTHudControl : NSObject

- (UIView *)contentView;
- (void)destroyContentView;
- (void)setHudValue:(NSString *)value forKey:(NSString *)key;
- (NSDictionary *)allHudItem;

@end

