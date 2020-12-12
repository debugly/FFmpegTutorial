//
//  MRVerticallyCenteredTextFieldCell.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/12.
//
// https://zhuanlan.zhihu.com/p/58844040

#import "MRVerticallyCenteredTextFieldCell.h"

@implementation MRVerticallyCenteredTextFieldCell

- (NSRect)drawingRectForBounds:(NSRect)rect
{
    NSRect aRect = [super drawingRectForBounds:rect];
    NSSize textSize = [self cellSizeForBounds:rect];
    CGFloat heightDelta = aRect.size.height - textSize.height;
    if (heightDelta > 0) {
        aRect.size.height = textSize.height;
        aRect.origin.y += heightDelta * 0.5;
    }
    return aRect;
}

@end
