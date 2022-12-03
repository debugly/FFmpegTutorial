//
//  MRCrossPlatformUtil.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/12/3.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#ifndef MRCrossPlatformUtil_h
#define MRCrossPlatformUtil_h

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#elif TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
typedef UIViewController NSViewController;
typedef UITextView NSTextView;
typedef UIButton NSButton;
typedef UITextField NSTextField;
typedef UIActivityIndicatorView NSProgressIndicator;

@interface UIActivityIndicatorView (_appkit_)

- (void)startAnimation:(id)a;
- (void)stopAnimation:(id)a;

@end

@interface UITextView (_appkit_)

- (void)setString:(NSString *)t;

@end

@interface UITextField (_appkit_)

- (void)setStringValue:(NSString *)t;
- (NSString *)stringValue;

- (void)setPlaceholderString:(NSString *)t;
- (NSString *)placeholderString;

@end

#endif

@interface MRBaseViewController : NSViewController

#if TARGET_OS_IPHONE
- (void)viewWillDisappear;
#endif

@end


#endif /* MRCrossPlatformUtil_h */
