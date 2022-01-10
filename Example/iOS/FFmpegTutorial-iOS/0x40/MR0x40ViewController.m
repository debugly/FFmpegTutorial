//
//  MR0x40ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//

#import "MR0x40ViewController.h"
#import "MRRWeakProxy.h"
#import "MR0x40VideoRenderer.h"
#import <FFmpegTutorial/MRConvertUtil.h>

@interface MR0x40ViewController ()

@property (weak, nonatomic) IBOutlet MR0x40VideoRenderer *renderView;
@property (weak, nonatomic) NSTimer *timer;
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
//0，1
@property (nonatomic,assign) NSInteger type;

@end

@implementation MR0x40ViewController

- (void)dealloc
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    if(self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.renderView.contentMode = UIViewContentModeScaleAspectFit;
    
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.016 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (IBAction)onExchange:(UISegmentedControl *)sender
{
    self.type = sender.selectedSegmentIndex;
}

- (CMSampleBufferRef)sampleBuffer:(int)w h:(int)h
{
    CVReturn theError;
    if (!self.pixelBufferPool){
        
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
//        不设置也行，也没有查到具体的资料，如何计算该值，按64对齐是之前猜出来的😶
//        int linesize = BYTE_ALIGN_64(self.vwidth);
//        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    if (self.type == 1) {
        pixelBuffer = [MRConvertUtil grayColorBarPixelBuffer:w h:h opt:self.pixelBufferPool];
    } else {
        pixelBuffer = [MRConvertUtil snowPixelBuffer:w h:h opt:self.pixelBufferPool];
    }

    return [MRConvertUtil cmSampleBufferRefFromCVPixelBufferRef:pixelBuffer];
}

- (void)onTimer:(NSTimer *)sender
{
    CMSampleBufferRef sampleBuffer = [self sampleBuffer:CGRectGetWidth(self.renderView.bounds) h:CGRectGetHeight(self.renderView.bounds)];
    [self.renderView enqueueSampleBuffer:sampleBuffer];
}

@end
