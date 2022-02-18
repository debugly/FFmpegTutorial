//
//  RootTableRowView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/27.
//

#import "RootTableRowView.h"

@interface RootTableRowView ()

@property (nonatomic, weak) NSTextField *titleLb;
@property (nonatomic, weak) NSTextField *detailLb;
@property (nonatomic, weak) NSImageView *arrowView;

@end

@implementation RootTableRowView

- (NSTextField *)createLabel
{
    NSTextField *tx = [[NSTextField alloc] init];
    tx.editable = NO;
    //点击的时候不显示蓝色外框
    tx.focusRingType = NSFocusRingTypeNone;
    tx.bordered = NO;
    tx.backgroundColor = [NSColor clearColor];
    tx.font = [NSFont systemFontOfSize:14];
    return tx;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        
        [self setWantsLayer:YES];
        
        NSTextField *titleLb = [self createLabel];
        NSTextField *detailLB = [self createLabel];
        detailLB.alignment = NSTextAlignmentRight;
        
        [self addSubview:titleLb];
        [self addSubview:detailLB];
        
        self.titleLb = titleLb;
        self.detailLb = detailLB;
        
        NSImageView *arrowView = [[NSImageView alloc] init];
        arrowView.image = [NSImage imageNamed:@"arrow"];
        [self addSubview:arrowView];
        self.arrowView = arrowView;
    }
    return self;
}

- (void)updateTitle:(NSString *)title
{
    if (!title) {
        title = @"";
    }
    self.titleLb.stringValue = title;
}

- (void)updateDetail:(NSString *)title
{
    if (!title) {
        title = @"";
    }
    self.detailLb.stringValue = title;
}

- (void)updateArrow:(BOOL)hide
{
    self.arrowView.hidden = hide;
}

- (void)layoutNormalCell {
    CGRect frameRect = self.bounds;
    CGFloat padding = 15;
    
    CGFloat minX = padding;
    CGFloat maxX = CGRectGetWidth(frameRect);
    CGFloat height = CGRectGetHeight(frameRect);
    
    {
        CGFloat aPadding = 2;
        CGFloat h = height / 2.0;
        CGFloat w = h;
        CGFloat y = (height - h)/2.0;
        CGFloat x = (maxX - w) - aPadding;
        NSRect rect = NSMakeRect(x, y, h, w);
        self.arrowView.frame = rect;
        maxX = x - aPadding;
    }
    
    {
        NSRect rect = self.bounds;
        rect.size.width = (maxX - minX)/2.0;
        CGSize labelSize = [self.titleLb sizeThatFits:rect.size];
        rect.origin.x = minX;
        rect.origin.y = (height - labelSize.height)/2.0;
        rect.size = labelSize;
        self.titleLb.frame = rect;
        minX = CGRectGetMaxX(rect);
        minX += padding;
    }
    
    {
        NSRect rect = self.bounds;
        rect.size.width = maxX - minX;
        CGSize labelSize = [self.detailLb sizeThatFits:rect.size];
        rect.origin.x = minX;
        rect.origin.y = (height - labelSize.height)/2.0;
        rect.size.height = labelSize.height;
        self.detailLb.frame = rect;
    }
}

- (void)layoutSectionCell {
    
    CGFloat height = CGRectGetHeight(self.bounds);
    {
        NSRect rect = self.bounds;
        CGSize labelSize = [self.titleLb sizeThatFits:rect.size];
        rect.origin.x = 5;
        rect.origin.y = (height - labelSize.height)/2.0;
        rect.size = labelSize;
        self.titleLb.frame = rect;
    }
}

- (void)layout
{
    if (self.isGroupRowStyle) {
        self.arrowView.hidden = YES;
        self.detailLb.hidden = YES;
        [self layoutSectionCell];
        self.layer.backgroundColor = [[NSColor colorWithWhite:230.0/255.0 alpha:1.0] CGColor];
    } else {
        self.arrowView.hidden = NO;
        self.detailLb.hidden = NO;
        [self layoutNormalCell];
        self.layer.backgroundColor = [[NSColor whiteColor] CGColor];
    }
}

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
    if (self.isGroupRowStyle) {
        return;
    }
    switch (self.sepStyle) {
        case KSeparactorStyleFull:
        case KSeparactorStyleHeadPadding:
        {
            CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
            CGContextSetStrokeColorWithColor(context, (__bridge CGColorRef)[NSColor colorWithWhite:0.1 alpha:0.1]);
            CGContextSetLineWidth(context, 1);
            //    CGFloat dashArray[] = {3,1};
            //    CGContextSetLineDash(context, 1, dashArray, 1);//跳过3个再画虚线，所以刚开始有6-（3-2）=5个虚点
            CGFloat y = CGRectGetHeight(dirtyRect);
            if (self.sepStyle == KSeparactorStyleFull) {
                CGContextMoveToPoint(context, 0, y);
            } else {
                CGContextMoveToPoint(context, 15, y);
            }
            
            CGContextAddLineToPoint(context, CGRectGetWidth(dirtyRect), y);
            CGContextStrokePath(context);
        }
            break;
        case KSeparactorStyleNone:
        {
            
        }
            break;
    }
}

@end
