//
//  MR0x201ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/21.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x201ViewController.h"
#import <FFmpegTutorial/FFPlayer0x20.h>
#import <FFmpegTutorial/MRHudControl.h>
#import "MRRWeakProxy.h"
#import "MR0x201VideoRenderer.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

#define QUEUE_BUFFER_SIZE 3
#define MIN_SIZE_PER_FRAME 4096


@interface MR0x201ViewController ()<FFPlayer0x20Delegate>

{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
#endif
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];
}

@property (strong) FFPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x201VideoRenderer *videoRenderer;

@property (strong) MRHudControl *hud;
@property (weak) NSTimer *timer;

//声音大小
@property (nonatomic,assign) float outputVolume;
//最终音频格式（采样深度）
@property (nonatomic,assign) MRSampleFormat finalSampleFmt;
//音频渲染
@property (nonatomic,assign) AudioQueueRef audioQueue;
//音频信息结构体
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;

@end

@implementation MR0x201ViewController

- (void)_stop
{
    if(_audioQueue){
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
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
    
    [self.hud destroyContentView];
    self.hud = nil;
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

- (void)playAudio
{
    BOOL full = YES;
    for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
        AudioQueueBufferRef ref = self->audioQueueBuffers[i];
        UInt32 gotBytes = [self renderFramesToBuffer:ref queue:self.audioQueue];
        if (gotBytes == 0) {
            full = NO;
            break;
        }
    }
    
    if (full) {
        OSStatus status = AudioQueueStart(self.audioQueue, NULL);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img
{
    CFRetain(img);
    MR_sync_main_queue(^{
        [self.videoRenderer displayPixelBuffer:img];
        CFRelease(img);
        
        //显示画面的时候，开始播放音频
        static bool started = false;
        if (!started) {
            [self playAudio];
            started = true;
        }
        
    });
}

- (void)onInitAudioRender:(MRSampleFormat)fmt
{
    MR_async_main_queue(^{
        [self setupAudioRender:fmt];
    });
}

- (void)setupAudioRender:(MRSampleFormat)fmt
{
    {
        // ----- Audio Queue Setup -----
        
        _outputFormat.mSampleRate = self.player.supportedSampleRate;
        _outputFormat.mChannelsPerFrame = 2;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        _outputFormat.mReserved = 0;
        
        bool isFloat  = MR_Sample_Fmt_Is_FloatX(fmt);
        bool isS16    = MR_Sample_Fmt_Is_S16X(fmt);
        bool isPacket = MR_Sample_Fmt_Is_Packet(fmt);
        NSAssert(isPacket, @"Audio Queue Support packet fmt only!");
        
        if (isS16){
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
        } else if (isFloat){
            _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(float) * 8;
        }
        
        //packed only!
        _outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
        _outputFormat.mBytesPerFrame = (_outputFormat.mBitsPerChannel / 8) * _outputFormat.mChannelsPerFrame;
        _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
        
        OSStatus status = AudioQueueNewOutput(&self->_outputFormat, MRAudioQueueOutputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self->_audioQueue);
        
        NSAssert(noErr == status, @"AudioQueueNewOutput");
        
        //初始化音频缓冲区--audioQueueBuffers为结构体数组
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            int result = AudioQueueAllocateBuffer(self.audioQueue,MIN_SIZE_PER_FRAME, &self->audioQueueBuffers[i]);
            NSAssert(noErr == result, @"AudioQueueAllocateBuffer");
        }
        
        self.finalSampleFmt = fmt;
    }
}

#pragma mark - 音频

//音频渲染回调；
static void MRAudioQueueOutputCallback(
                                 void * __nullable       inUserData,
                                 AudioQueueRef           inAQ,
                                 AudioQueueBufferRef     inBuffer)
{
    MR0x201ViewController *am = (__bridge MR0x201ViewController *)inUserData;
    [am renderFramesToBuffer:inBuffer queue:inAQ];
}

- (UInt32)renderFramesToBuffer:(AudioQueueBufferRef) inBuffer queue:(AudioQueueRef)inAQ
{
    //1、填充数据
    UInt32 gotBytes = [self fetchPacketSample:inBuffer->mAudioData wantBytes:inBuffer->mAudioDataBytesCapacity];
    inBuffer->mAudioDataByteSize = gotBytes;
    
    // 2、通知 AudioQueue 有可以播放的 buffer 了
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    return gotBytes;
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
    
    FFPlayer0x20 *player = [[FFPlayer0x20 alloc] init];
    player.contentPath = url;
    
    [self.indicatorView startAnimation:nil];
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
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
