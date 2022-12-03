//
//  MRGLVersionViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/14.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRGLVersionViewController.h"
#import <FFmpegTutorial/FFTVersionHelper.h>
#if TARGET_OS_OSX
#import <FFmpegTutorial/FFTOpenGLVersionHelper.h>
#endif

@interface MRGLVersionViewController ()

@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation MRGLVersionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    __block NSString *info = [FFTVersionHelper ffmpegAllInfo];
#if TARGET_OS_OSX
    [FFTOpenGLVersionHelper prepareOpenGLContext:^{
        info = [info stringByAppendingString:[FFTOpenGLVersionHelper openglAllInfo:NO]];
    } forLegacy:NO];
    
    [FFTOpenGLVersionHelper prepareOpenGLContext:^{
        info = [info stringByAppendingString:[FFTOpenGLVersionHelper openglAllInfo:YES]];
    } forLegacy:YES];
#endif
    self.textView.string = info;
}

@end
