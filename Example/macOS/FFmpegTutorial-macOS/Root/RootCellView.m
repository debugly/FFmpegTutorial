//
//  RootCellView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/25.
//

#import "RootCellView.h"

@interface RootCellView ()

@property (nonatomic, weak) NSTextField *titleLb;
@property (nonatomic, weak) NSTextField *detailLb;
@property (nonatomic, weak) NSImageView *arrowView;

@end

@implementation RootCellView

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
        
//        [self setWantsLayer:YES];
//        self.layer.backgroundColor = [[NSColor redColor] CGColor];
        
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

- (void)layout
{
    CGRect frameRect = self.bounds;
    CGFloat padding = 15;
    
    CGFloat minX = padding;
    CGFloat maxX = CGRectGetWidth(frameRect);
    CGFloat height = CGRectGetHeight(frameRect);
    
    {
        CGFloat aPadding = 6;
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

@end
