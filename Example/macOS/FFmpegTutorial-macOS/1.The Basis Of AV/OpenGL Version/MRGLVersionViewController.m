//
//  MRGLVersionViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/14.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRGLVersionViewController.h"
#import <FFmpegTutorial/FFTVersionHelper.h>
#import <FFmpegTutorial/FFTOpenGLVersionHelper.h>

@interface MRGLVersionViewController ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation MRGLVersionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    __block NSString *info = [FFTVersionHelper ffmpegAllInfo];
    
    [FFTOpenGLVersionHelper prepareOpenGLContext:^{
        info = [info stringByAppendingString:[FFTOpenGLVersionHelper openglAllInfo:NO]];
    } forLegacy:NO];
    
    [FFTOpenGLVersionHelper prepareOpenGLContext:^{
        info = [info stringByAppendingString:[FFTOpenGLVersionHelper openglAllInfo:YES]];
    } forLegacy:YES];
    
    self.textView.string = info;
}

@end
