//
//  RootCellView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/25.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RootCellView : NSView

- (void)updateTitle:(NSString *)title;
- (void)updateDetail:(NSString *)title;
    
@end

NS_ASSUME_NONNULL_END
