//
//  MR0x40IndicatorCellView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/13.
//

#import "MR0x40IndicatorCellView.h"

@interface MR0x40IndicatorCellView ()

@property (nonatomic, strong) NSProgressIndicator *indicator;
@property (nonatomic, weak) NSImageView *imgView;

@end

@implementation MR0x40IndicatorCellView

- (void)prepareImgViewIfNeed
{
    if (!self.imgView) {
        NSImageView *imgView = [[NSImageView alloc] init];
        [self addSubview:imgView];
        self.imgView = imgView;
    }
}

- (void)prepareIndicatorIfNeed
{
    if (!self.indicator) {
        NSProgressIndicator *indicator = [[NSProgressIndicator alloc] init];
        indicator.style = NSProgressIndicatorStyleSpinning;
        indicator.displayedWhenStopped = NO;
        [self addSubview:indicator];
        self.indicator = indicator;
    }
}

- (void)layout
{
    NSView *view = nil;
    if (_indicator) {
        view = _indicator;
    } else if (_imgView) {
        view = _imgView;
    }
    
    if (view) {
        view.frame = CGRectMake(0, 0, 20, 20);
        CGFloat x = (CGRectGetWidth(self.bounds) - CGRectGetWidth(view.bounds)) / 2.0;
        CGFloat y = (CGRectGetHeight(self.bounds) - CGRectGetHeight(view.bounds)) / 2.0;
        CGRect rect = view.frame;
        rect.origin = CGPointMake(x, y);
        view.frame = rect;
    }
    
}

- (void)start
{
    if (_imgView) {
        [_imgView removeFromSuperview];
        _imgView = nil;
    }
    [self prepareIndicatorIfNeed];
    [self.indicator startAnimation:nil];
}

- (void)stop
{
    if (_indicator) {
        [_indicator stopAnimation:nil];
        [_indicator removeFromSuperview];
        _indicator = nil;
    }
    [self prepareImgViewIfNeed];
    self.imgView.image = [NSImage imageNamed:@"NSMenuOnStateTemplate"];
}

- (void)waiting
{
    if (_indicator) {
        [_indicator stopAnimation:nil];
        [_indicator removeFromSuperview];
        _indicator = nil;
    }
    [self prepareImgViewIfNeed];
    self.imgView.image = [NSImage imageNamed:@"NSTouchBarHistoryTemplate"];
}

- (void)wrong
{
    if (_indicator) {
        [_indicator stopAnimation:nil];
        [_indicator removeFromSuperview];
        _indicator = nil;
    }
    [self prepareImgViewIfNeed];
    self.imgView.image = [NSImage imageNamed:@"NSStopProgressFreestandingTemplate"];
}

@end
