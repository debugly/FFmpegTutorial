//
//  MR0x40TableHeaderCell.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/12.
//

#import "MR0x40TableHeaderCell.h"

@implementation MR0x40TableHeaderCell

- (NSFont *)font
{
    return [NSFont boldSystemFontOfSize:13];
}

- (NSRect)drawingRectForBounds:(NSRect)rect
{
    NSRect aRect = [super drawingRectForBounds:rect];
    NSSize textSize = [self cellSizeForBounds:rect];
    CGFloat heightDelta = aRect.size.height - textSize.height;
    if (heightDelta > 0) {
        aRect.size.height = textSize.height;
        aRect.origin.y += heightDelta * 0.5;
    }
    
    CGFloat widthDelta = aRect.size.width - textSize.width;
    if (widthDelta > 0) {
        aRect.origin.x += widthDelta * 0.5;
    }
    
    return aRect;
}

@end
