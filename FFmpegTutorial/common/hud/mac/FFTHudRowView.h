//
//  FFTHudRowView.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2022/4/6.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    KSeparactorStyleFull,
    KSeparactorStyleHeadPadding,
    KSeparactorStyleNone,
} KSeparactorStyle;

@interface FFTHudRowView : NSTableRowView <NSUserInterfaceItemIdentification>

@property KSeparactorStyle sepStyle;

- (void)updateTitle:(NSString *)title;
- (void)updateDetail:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
