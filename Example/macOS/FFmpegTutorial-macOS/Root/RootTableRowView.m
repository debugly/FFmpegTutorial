//
//  RootTableRowView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/27.
//

#import "RootTableRowView.h"

@implementation RootTableRowView

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
//    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
//    CGContextSetFillColorWithColor(context, (__bridge CGColorRef)[NSColor secondarySelectedControlColor]);
//    CGContextFillRect(context, dirtyRect);
//
//    [[NSColor colorWithWhite:0.5 alpha:0.5] drawSwatchInRect:dirtyRect];
    [[NSColor secondarySelectedControlColor] set];
    NSRectFill(dirtyRect);
}

//- (void)drawSeparatorInRect:(NSRect)dirtyRect
//{
//
//}

//如果放在drawSeparatorInRect画，必须设置gridStyleMask不为None，但是多余空白行的线会顶到头
- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetStrokeColorWithColor(context, (__bridge CGColorRef)[NSColor colorWithWhite:0.1 alpha:0.1]);
    CGContextSetLineWidth(context, 1);
//    CGFloat dashArray[] = {3,1};
//    CGContextSetLineDash(context, 1, dashArray, 1);//跳过3个再画虚线，所以刚开始有6-（3-2）=5个虚点
    CGFloat y = CGRectGetHeight(dirtyRect);
    CGContextMoveToPoint(context, 15, y);
    CGContextAddLineToPoint(context, CGRectGetWidth(dirtyRect), y);
    CGContextStrokePath(context);
}

@end
