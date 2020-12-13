//
//  MR0x40IndicatorCellView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/13.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x40IndicatorCellView : NSView

- (void)start;
- (void)stop;
- (void)waiting;
- (void)wrong;

@end

NS_ASSUME_NONNULL_END
