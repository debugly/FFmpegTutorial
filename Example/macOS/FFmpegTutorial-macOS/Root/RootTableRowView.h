//
//  RootTableRowView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/27.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    KSeparactorStyleFull,
    KSeparactorStyleHeadPadding,
    KSeparactorStyleNone,
} KSeparactorStyle;

@interface RootTableRowView : NSTableRowView <NSUserInterfaceItemIdentification>

@property KSeparactorStyle sepStyle;

- (void)updateTitle:(NSString *)title;
- (void)updateDetail:(NSString *)title;
- (void)updateArrow:(BOOL)hide;

@end

NS_ASSUME_NONNULL_END
