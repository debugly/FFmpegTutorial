//
//  MR0x40CellView.m
//  FFmpegTutorial-macOS
//
//  Created by Matt Reach on 2020/12/11.
//

#import "MR0x40CellView.h"
#import "MRVerticallyCenteredTextFieldCell.h"

@interface MR0x40CellView ()

@property (nonatomic, weak) NSTextField *label;

@end

@implementation MR0x40CellView

- (NSTextField *)createLabel
{
    NSTextField *tx = [[NSTextField alloc] init];
    tx.editable = NO;
    //点击的时候不显示蓝色外框
    tx.focusRingType = NSFocusRingTypeNone;
    tx.bordered = NO;
    tx.backgroundColor = [NSColor clearColor];
    tx.font = [NSFont systemFontOfSize:14];
    [tx setCell:[MRVerticallyCenteredTextFieldCell new]];
    return tx;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        
//        [self setWantsLayer:YES];
//        self.layer.backgroundColor = [[NSColor redColor] CGColor];
        
        NSTextField *label = [self createLabel];
        [self addSubview:label];
        label.frame = self.bounds;
        label.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
        self.label = label;
    }
    return self;
}

- (void)updateText:(NSString *)text
{
    if (!text) {
        text = @"";
    }
    self.label.stringValue = text;
}

@end
