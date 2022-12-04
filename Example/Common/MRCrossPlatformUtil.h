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
CGContextRef __nullable UIGraphicsGetCurrentContext(void);
#elif TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
typedef UIViewController NSViewController;
typedef UITextView NSTextView;
typedef UIButton NSButton;
typedef UITextField NSTextField;
typedef UIActivityIndicatorView NSProgressIndicator;
typedef UIImageView NSImageView;
typedef UIColor NSColor;
typedef UIImage NSImage;
typedef UIView NSView;
typedef UIScreen NSScreen;

#define NSViewWidthSizable  UIViewAutoresizingFlexibleWidth
#define NSViewHeightSizable UIViewAutoresizingFlexibleHeight
#define NSViewMinXMargin    UIViewAutoresizingFlexibleLeftMargin

#define NSRectFill(rect) CGContextFillRect(UIGraphicsGetCurrentContext(), rect);

@interface UIImage (_appkit)

- (instancetype)initWithCGImage:(CGImageRef)cgImage size:(CGSize)size;

@end

@interface UIView (_appkit_)

- (void)setWantsLayer:(BOOL)w;
- (void)setNeedsDisplay:(BOOL)n;

@end

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

@interface MRSegmentedControl : UISegmentedControl

- (void)insertSegmentWithTitle:(NSString *)title atIndex:(NSUInteger)segment animated:(BOOL)animated tag:(NSInteger)tag;
- (NSInteger)tagForCurrentSelected;

@end
#endif

@interface MRBaseViewController : NSViewController

#if TARGET_OS_IPHONE
- (void)viewWillDisappear;
#endif
- (int)alert:(NSString *)title msg:(NSString *)msg;

@end


#endif /* MRCrossPlatformUtil_h */
