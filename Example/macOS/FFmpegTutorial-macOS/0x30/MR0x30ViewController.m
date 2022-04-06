//
//  MR0x30ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/2/17.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x30ViewController.h"
#import <FFmpegTutorial/FFPlayer0x30.h>
#import "MRRWeakProxy.h"
#import "MR0x30VideoRenderer.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"
#import "MR0x30AudioRenderer.h"
#import <FFmpegTutorial/MRHudControl.h>

@interface MR0x30ViewController ()<FFPlayer0x30Delegate>

@property (strong) FFPlayer0x30 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x30VideoRenderer *videoRenderer;
@property (strong) MRHudControl *hud;
@property (weak) NSTimer *timer;
@property (strong) MR0x30AudioRenderer *audioRenderer;

@end

@implementation MR0x30ViewController

- (void)_stop
{
    if(_audioRenderer){
        [_audioRenderer pause];
        _audioRenderer = nil;
    }
    
#if DEBUG_RECORD_PCM_TO_FILE
    fclose(file_pcm_l);
#endif
    
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
}

- (void)dealloc
{
    [self _stop];
}

- (void)prepareTickTimerIfNeed
{
    if (self.timer && ![self.timer isValid]) {
        return;
    }
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)player:(FFPlayer0x30 *)player reveiveFrameToRenderer:(CVPixelBufferRef)img
{
    CFRetain(img);
    MR_sync_main_queue(^{
        [self.videoRenderer displayPixelBuffer:img];
        CFRelease(img);
    });
}

- (void)player:(FFPlayer0x30 *)player onInitAudioRender:(MRSampleFormat)fmt
{
    MR_async_main_queue(^{
        [self setupAudioRender:fmt];
    });
}

- (void)onBufferFull:(FFPlayer0x30 *)player
{
    [self.audioRenderer play];
}

- (void)onBufferEmpty:(FFPlayer0x30 *)player
{
    [self.audioRenderer pause];
}

- (void)setupAudioRender:(MRSampleFormat)fmt
{
    if (!self.audioRenderer) {
        MR0x30AudioRenderer *audioRenderer = [[MR0x30AudioRenderer alloc] initWithFmt:fmt preferredAudioQueue:YES sampleRate:self.player.supportedSampleRate];
        
        __weakSelf__
        [audioRenderer onFetchPacketSample:^UInt32(uint8_t * _Nonnull buffer, UInt32 bufferSize) {
            __strongSelf__
            return [self fetchPacketSample:buffer wantBytes:bufferSize];
        }];
        
        [audioRenderer onFetchPlanarSample:^UInt32(uint8_t * _Nonnull left, UInt32 leftSize, uint8_t * _Nonnull right, UInt32 rightSize) {
            __strongSelf__
            return [self fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
        }];
        
        self.audioRenderer = audioRenderer;
    }
}

#pragma mark - 音频

- (UInt32)fetchPlanarSample:(uint8_t*)left
                  leftSize:(UInt32)leftSize
                     right:(uint8_t*)right
                 rightSize:(UInt32)rightSize
{
    UInt32 filled = [self.player fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
    return filled;
}

- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
    
    #if DEBUG_RECORD_PCM_TO_FILE
    fwrite(buffer, 1, filled, file_pcm_l);
    #endif
    return filled;
}


- (void)onTimer:(NSTimer *)sender
{
    [self.indicatorView stopAnimation:nil];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    MR_PACKET_SIZE pktSize = [self.player peekPacketBufferStatus];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",pktSize.audio_pkt_size] forKey:@"a-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",pktSize.video_pkt_size] forKey:@"v-pack"];
}

- (void)alert:(NSString *)msg
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"知道了"];
    [alert setMessageText:@"错误提示"];
    [alert setInformativeText:msg];
    [alert setAlertStyle:NSInformationalAlertStyle];
    NSModalResponse returnCode = [alert runModal];
    
    if (returnCode == NSAlertFirstButtonReturn)
    {
        //nothing todo
    }
    else if (returnCode == NSAlertSecondButtonReturn)
    {
        
    }
}

- (void)parseURL:(NSString *)url
{
    [self _stop];
    
    self.hud = [[MRHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.videoRenderer addSubview:hudView];
    CGRect rect = self.videoRenderer.bounds;
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 150);
    rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
    [hudView setFrame:rect];
    hudView.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable;
    
    FFPlayer0x30 *player = [[FFPlayer0x30 alloc] init];
    player.contentPath = url;
    
    [self.indicatorView startAnimation:nil];
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player.delegate = nil;
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    
    [player onVideoEnds:^{
        __strongSelf__
        [self.player asyncStop];
        self.player.delegate = nil;
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats = MR_PIX_FMT_MASK_NV12;
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16 | MR_SAMPLE_FMT_MASK_FLT;
    
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    self.player = player;
    [self prepareTickTimerIfNeed];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    
    [self.videoRenderer setWantsLayer:YES];
    self.videoRenderer.layer.backgroundColor = [[NSColor redColor]CGColor];
    
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
#endif
}

#pragma - mark actions

- (IBAction)go:(NSButton *)sender
{
    if (self.inputField.stringValue.length > 0) {
        [self parseURL:self.inputField.stringValue];
    } else {
        self.inputField.placeholderString = @"请输入视频地址";
    }
}

- (IBAction)onExchangeUploadTextureMethod:(NSButton *)sender
{
    [self.videoRenderer exchangeUploadTextureMethod];
}

- (IBAction)onSaveSnapshot:(NSButton *)sender
{
    NSImage *img = [self.videoRenderer snapshot];
    NSString *videoName = [[NSURL URLWithString:self.player.contentPath] lastPathComponent];
    if ([videoName isEqualToString:@"/"]) {
        videoName = @"未知";
    }
    NSString *folder = [NSFileManager mr_DirWithType:NSPicturesDirectory WithPathComponents:@[@"FFmpegTutorial",videoName]];
    long timestamp = [NSDate timeIntervalSinceReferenceDate] * 1000;
    NSString *filePath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg",timestamp]];
    [MRUtil saveImageToFile:[MRUtil nsImage2cg:img] path:filePath];
    NSLog(@"img:%@",filePath);
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
            
    if (item.tag == 1) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFit];
    }
}

@end
