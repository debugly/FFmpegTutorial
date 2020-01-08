//
//  ViewController.m
//  FFmpeg006-1
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/samplefmt.h>
#import <libswscale/swscale.h>
#import "MRVideoFrame.h"
#import "MRPacketQueue.h"
#import "MRConvertUtil.h"
#import "MRVideoRenderView.h"

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

#define USE_PIXEL_BUFFER_POLL 1
#define BYTE_ALIGN_64(_s_) (( _s_ + 63)/64 * 64)

@interface ViewController ()

///画面高度，单位像素
@property (nonatomic,assign) int vwidth;
@property (nonatomic,assign) int aligned_width;
@property (nonatomic,assign) int vheight;

@property (strong, nonatomic) MRVideoRenderView *renderView;
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;

@end

@implementation ViewController

- (void)dealloc
{
    if(self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.renderView = [[MRVideoRenderView alloc] init];
    self.renderView.frame = self.view.bounds;
    self.renderView.contentMode = UIViewContentModeScaleAspectFit;
    self.renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.renderView];
    
    self.vwidth = CGRectGetWidth(self.view.bounds);
    self.vheight = CGRectGetHeight(self.view.bounds);
    self.aligned_width = BYTE_ALIGN_64(self.vwidth);
    
    // 启动渲染驱动
    [self videoTick];
}

- (CMSampleBufferRef)sampleBuffer:(int)w h:(int)h
{
    CVReturn theError;
    if (!self.pixelBufferPool){
        int linesize = self.aligned_width;
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = [MRConvertUtil snowPixelBuffer:w linesize:self.aligned_width h:h opt:self.pixelBufferPool];
    
    return [MRConvertUtil cmSampleBufferRefFromCVPixelBufferRef:pixelBuffer];
}

#pragma mark - 渲染驱动

- (void)videoTick
{
    CMSampleBufferRef sampleBuffer = [self sampleBuffer:self.vwidth h:self.vheight];
    
    [self.renderView enqueueSampleBuffer:sampleBuffer];
    NSTimeInterval time = 1 / 25.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self videoTick];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
