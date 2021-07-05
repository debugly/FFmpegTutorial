//
//  MR0x01ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/14.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x01ViewController.h"
#import <FFmpegTutorial/FFVersionHelper.h>

@interface MR0x01ViewController ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation MR0x01ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.textView.string = [FFVersionHelper ffmpegAllInfo];
}

@end
