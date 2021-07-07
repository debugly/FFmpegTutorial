//
//  MR0x02ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x02ViewController.h"
#import <FFmpegTutorial/FFPlayer0x02.h>

@interface MR0x02ViewController ()

@property (strong) FFPlayer0x02 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (assign) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;

@end

@implementation MR0x02ViewController

- (void)dealloc
{
    if (self.player) {
        [self.player stop];
        self.player = nil;
    }
}

- (IBAction)go:(NSButton *)sender
{
    if (self.inputField.stringValue.length > 0) {
        [self parseURL:self.inputField.stringValue];
    } else {
        self.inputField.placeholderString = @"请输入视频地址";
    }
}

- (void)parseURL:(NSString *)url
{
    [self.indicatorView startAnimation:nil];
    if (self.player) {
        [self.player stop];
    }
    
    FFPlayer0x02 *player = [[FFPlayer0x02 alloc] init];
    player.contentPath = url;
    [player prepareToPlay];
    __weakSelf__
    [player openStream:^(NSError * _Nullable error, NSString * _Nullable info) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        if (error) {
            self.textView.string = [error localizedDescription];
        } else {
            self.textView.string = info;
        }
        self.player = nil;
    }];
    
    self.player = player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
}

@end
