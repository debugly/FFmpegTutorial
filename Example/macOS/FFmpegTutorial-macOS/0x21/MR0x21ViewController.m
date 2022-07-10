//
//  MR0x21ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x21ViewController.h"
#import <FFmpegTutorial/FFPlayer0x20.h>
#import <FFmpegTutorial/MRHudControl.h>
#import <FFmpegTutorial/MRConvertUtil.h>
#import <FFmpegTutorial/MRDispatch.h>
#import <FFmpegTutorial/FFPlayerHeader.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "MR0x21VideoRenderer.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MR0x21ViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x21VideoRenderer *videoRenderer;

@property (strong) MRHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;
@property (copy) NSString *audioSamplelInfo;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) MRPixelFormat videoFmt;
@property (nonatomic,assign) MRSampleFormat audioFmt;

//音频渲染
@property (nonatomic,assign) AudioUnit audioUnit;
@property (atomic,assign) AVFrame *audioFrame;
@property (atomic,assign) int audioFrameRead;

@end

@implementation MR0x21ViewController

- (void)_stop
{
    [self stopAudio];
    
    if (_audioFrame) {
        av_frame_free(&_audioFrame);
    }
    
#if DEBUG_RECORD_PCM_TO_FILE
    [self close_all_file];
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    [self.videoRenderer setWantsLayer:YES];
    self.videoRenderer.layer.backgroundColor = [[NSColor redColor]CGColor];
    
    self.hud = [[MRHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    CGRect rect = self.view.bounds;
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 240);
    rect.size.height = CGRectGetHeight(self.view.bounds) - 210;
    rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
    [hudView setFrame:rect];
    hudView.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    
    _sampleRate = 44100;
    _videoFmt = MR_PIX_FMT_NV12;
    _audioFmt = MR_SAMPLE_FMT_S16;
    _audioFrameRead = 0;
    [self.hud setHudValue:@"0" forKey:@"ioSurface"];
    _audioFrame = av_frame_alloc();
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

- (void)onTimer:(NSTimer *)sender
{
    [self.indicatorView stopAnimation:nil];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.videoPixelInfo] forKey:@"v-pixel"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSamplelInfo] forKey:@"a-sample"];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    [self.timer invalidate];
    self.timer = nil;

    [self close_all_file];
    [self.indicatorView startAnimation:nil];
    
    FFPlayer0x20 *player = [[FFPlayer0x20 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormat  = _videoFmt;
    player.supportedSampleRate   = _sampleRate;
    player.supportedSampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(NSDictionary * _Nonnull info) {
        __strongSelf__
        
        NSLog(@"---SteamInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
        
        int width  = [info[kFFPlayer0x20Width] intValue];
        int height = [info[kFFPlayer0x20Height] intValue];
        self.videoRenderer.videoSize = CGSizeMake(width, height);
        
        [self prepareTickTimerIfNeed];
        [self setupAudioRender:self.audioFmt sampleRate:self.sampleRate];
        [self playAudio];
    };
    
    player.onError = ^(NSError * _Nonnull e) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    player.onDecoderFrame = ^(int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        //video
        if (type == 1) {
            mr_msleep(30);
            @autoreleasepool {
                [self displayVideoFrame:frame];
            }
        }
        //audio
        else if (type == 2) {
            [self displayAudioFrame:frame];
        }
    };
    [player prepareToPlay];
    [player play];
    self.player = player;
}

#pragma - mark Video

- (void)displayVideoFrame:(AVFrame *)frame
{
    CVPixelBufferRef img = [MRConvertUtil pixelBufferFromAVFrame:frame opt:NULL];
    int width  = (int)CVPixelBufferGetWidth(img);
    int height = (int)CVPixelBufferGetHeight(img);
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,width,height];
    
    CFRetain(img);
    mr_sync_main_queue(^{
        [self.videoRenderer displayPixelBuffer:img];
        CFRelease(img);
    });
}

#pragma - mark Audio

- (void)playAudio
{
    if (self.audioUnit) {
        OSStatus status = AudioOutputUnitStart(self.audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)pauseAudio
{
    if (self.audioUnit) {
        OSStatus status = AudioOutputUnitStop(self.audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)stopAudio
{
    if (_audioUnit) {
        OSStatus status = AudioOutputUnitStop(_audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
        _audioUnit = NULL;
    }
}

- (void)close_all_file
{
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l) {
        fflush(file_pcm_l);
        fclose(file_pcm_l);
        file_pcm_l = NULL;
    }
    if (file_pcm_r) {
        fflush(file_pcm_r);
        fclose(file_pcm_r);
        file_pcm_r = NULL;
    }
#endif
}

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(MRSampleFormat)sampleRate
{
    {
        // ----- Audio Unit Setup -----
#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
    #if TARGET_OS_IOS
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
    #else
        desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    #endif
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent component = AudioComponentFindNext(NULL, &desc);
        OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
        NSAssert(noErr == status, @"AudioComponentInstanceNew");
        
        AudioStreamBasicDescription outputFormat;
        
        UInt32 size = sizeof(outputFormat);
        // 获取默认的输入信息
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputFormat, &size);
        //设置采样率
        outputFormat.mSampleRate = sampleRate;
        /**不使用视频的原声道数_audioCodecCtx->channels;
         mChannelsPerFrame 这个值决定了后续AudioUnit索要数据时 ioData->mNumberBuffers 的值！
         如果写成1会影响Planar类型，就不会开两个buffer了！！因此这里写死为2！
         */
        outputFormat.mChannelsPerFrame = 2;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mReserved = 0;
        
        bool isFloat  = MR_Sample_Fmt_Is_FloatX(fmt);
        bool isS16    = MR_Sample_Fmt_Is_S16X(fmt);
        bool isPlanar = MR_Sample_Fmt_Is_Planar(fmt);
        
        if (isS16){
            outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
        } else if (isFloat){
            outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(float) * 8;
        } else {
            NSAssert(NO, @"不支持的音频采样格式%d",fmt);
        }
        
        if (isPlanar) {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            outputFormat.mBytesPerFrame = outputFormat.mBitsPerChannel / 8;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        } else {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
            outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        }
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &outputFormat, size);
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        //get之后刷新这个值；
        //_targetSampleRate  = (int)outputFormat.mSampleRate;
        
        UInt32 flag = 0;
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
        // Slap a render callback on the unit
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = MRRenderCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &callbackStruct,
                             sizeof(callbackStruct));
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        status = AudioUnitInitialize(_audioUnit);
        NSAssert(noErr == status, @"AudioUnitInitialize");
#undef kOutputBus
#undef kInputBus
    }
}

//音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    void * buffer[2] = { 0 };
    UInt32 bufferSize = 0;
    // 1. 将buffer数组全部置为0；
    for (int i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer audioBuffer = ioData->mBuffers[i];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
        buffer[i] = audioBuffer.mData;
        bufferSize = audioBuffer.mDataByteSize;
    }
    
    MR0x21ViewController *am = (__bridge MR0x21ViewController *)inRefCon;
    [am fillBuffers:buffer size:bufferSize];
    return noErr;
}

- (void)fillBuffers:(void *[2])buffer
               size:(UInt32)bufferSize
{
    for(int i = 0; i < 2; i++) {
        void *dst = buffer[i];
        if (NULL != dst) {
            int leave = self.audioFrame->linesize[i] - self.audioFrameRead;
            if (leave > 0) {
                int size = MIN(bufferSize,leave);
                self.audioFrameRead += size;
                void *src = self.audioFrame->data[i] + self.audioFrameRead;
                [self fillBuffer:dst src:src size:size];
#if DEBUG_RECORD_PCM_TO_FILE
                const char *fmt_str = av_sample_fmt_to_string(_audioFrame->format);
                if (i == 0) {
                    if (file_pcm_l == NULL) {
                        NSString *fileName = [NSString stringWithFormat:@"L-%s-%d.pcm",fmt_str,_audioFrame->sample_rate];
                        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                        NSLog(@"create file:%s",l);
                        file_pcm_l = fopen(l, "wb+");
                    }
                    [self writePCM:file_pcm_l src:src size:size];
                } else if (i == 1) {
                    if (file_pcm_r == NULL) {
                        NSString *fileName = [NSString stringWithFormat:@"R-%s-%d.pcm",fmt_str,_audioFrame->sample_rate];
                        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                        NSLog(@"create file:%s",r);
                        file_pcm_r = fopen(r, "wb+");
                    }
                    [self writePCM:file_pcm_r src:src size:size];
                }
#endif
            } else {
                av_frame_unref(self.audioFrame);
                self.audioFrameRead = 0;
                NSLog(@"xxxxxxxxxxxxxxxxxxxxxxxxx");
            }
        } else {
            break;
        }
    }
}

- (void)fillBuffer:(void *)dst src:(void *)src size:(int)size
{
    memcpy(dst, src, size);
}

#if DEBUG_RECORD_PCM_TO_FILE
- (void)writePCM:(FILE *)fp src:(void *)src size:(int)size
{
    fwrite(src, size, 1, fp);
}
#endif

- (void)displayAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSamplelInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
    if (self.audioFrameRead > 0) {
        NSLog(@"yyyyyyyyyyyyyyyyyyyyyyyyyyyyy");
    }
    av_frame_move_ref(self.audioFrame, frame);
    self.audioFrameRead = 0;
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
    BOOL used = [self.videoRenderer exchangeUploadTextureMethod];
    if (used) {
        [sender setTitle:@"UseGeneral"];
    } else {
        [sender setTitle:@"UseIOSurface"];
    }
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",used] forKey:@"ioSurface"];
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

- (IBAction)onSelectAudioFmt:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int targetFmt = 0;
    if (item.tag == 1) {
        targetFmt = MR_SAMPLE_FMT_S16;
    } else if (item.tag == 2) {
        targetFmt = MR_SAMPLE_FMT_S16P;
    } else if (item.tag == 3) {
        targetFmt = MR_SAMPLE_FMT_FLT;
    } else if (item.tag == 4) {
        targetFmt = MR_SAMPLE_FMT_FLTP;
    }
    if (_audioFmt == targetFmt) {
        return;
    }
    _audioFmt = targetFmt;
    
    if (self.player) {
        NSString *url = self.player.contentPath;
        [self.player asyncStop];
        self.player = nil;
        [self parseURL:url];
    }
}

- (IBAction)onSelectSampleRate:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int sampleRate = 0;
    if (item.tag == 1) {
        sampleRate = 44100;
    } else if (item.tag == 2) {
        sampleRate = 44800;
    } else if (item.tag == 3) {
        sampleRate = 192000;
    }
    if (_sampleRate != sampleRate) {
        _sampleRate = sampleRate;
        if (self.player) {
            NSString *url = self.player.contentPath;
            [self.player asyncStop];
            self.player = nil;
            [self parseURL:url];
        }
    }
}

- (IBAction)onSelectVideoFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int targetFmt = 0;
    if (item.tag == 1) {
        //nv12
        targetFmt = MR_PIX_FMT_NV12;
    } else if (item.tag == 2) {
        //nv21
        targetFmt = MR_PIX_FMT_NV21;
    } else if (item.tag == 3) {
        //yuv420p
        targetFmt = MR_PIX_FMT_YUV420P;
    } else if (item.tag == 4) {
        //uyvy422
        targetFmt = MR_PIX_FMT_UYVY422;
    } else if (item.tag == 5) {
        //yuyv422
        targetFmt = MR_PIX_FMT_YUYV422;
    }
    if (_videoFmt == targetFmt) {
        return;
    }
    _videoFmt = targetFmt;
    
    if (self.player) {
        NSString *url = self.player.contentPath;
        [self.player asyncStop];
        self.player = nil;
        [self parseURL:url];
    }
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

@end
