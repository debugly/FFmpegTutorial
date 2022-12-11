//
//  MRAudioUnitViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRAudioUnitViewController.h"
#import <FFmpegTutorial/FFTPlayer0x20.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTAudioFrameQueue.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRRWeakProxy.h"

#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>


//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0


@interface MRAudioUnitViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFTPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
#if TARGET_OS_IPHONE
@property (weak, nonatomic) IBOutlet MRSegmentedControl *formatSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *rateSegCtrl;
#endif
@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *audioSampleInfo;
//音频渲染
@property (nonatomic,assign) AudioUnit audioUnit;
@property (atomic,strong) FFTAudioFrameQueue *audioFrameQueue;

@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) int audioFmt;

@end

@implementation MRAudioUnitViewController

- (void)_stop
{
    [self.audioFrameQueue cancel];
    [self stopAudio];
#if DEBUG_RECORD_PCM_TO_FILE
    [self close_all_file];
#endif
}

- (void)dealloc
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
    
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

- (void)onTimer:(NSTimer *)sender
{
    [self.indicatorView stopAnimation:nil];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.audioFrameQueue count]] forKey:@"a-frame-q"];
   
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSampleInfo] forKey:@"a-format"];
    
    [self.hud setHudValue:@"AudioUnit" forKey:@"renderer"];
}

- (void)alert:(NSString *)msg
{
    [self alert:@"知道了" msg:msg];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
        
        [self.timer invalidate];
        self.timer = nil;
    }
    
    [self.audioFrameQueue cancel];
    self.audioFrameQueue = nil;
    [self stopAudio];
    [self close_all_file];
    
    FFTPlayer0x20 *player = [[FFTPlayer0x20 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormat  = MR_PIX_FMT_NV21;
    player.supportedSampleRate   = _sampleRate;
    player.supportedSampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(FFTPlayer0x20 *player, NSDictionary * _Nonnull info) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        
        [self.indicatorView stopAnimation:nil];
        self.audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
        [self setupAudioRender:self.audioFmt sampleRate:self.sampleRate];
        [self playAudio];
        NSLog(@"---VideoInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
    };
    
    player.onError = ^(FFTPlayer0x20 *player, NSError * _Nonnull e) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    player.onDecoderFrame = ^(FFTPlayer0x20 *player, int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        //video
        if (type == 1) {
        }
        //audio
        else if (type == 2) {
            [self displayAudioFrame:frame];
        }
    };
    [player prepareToPlay];
    [player play];
    self.player = player;
    
    [self prepareTickTimerIfNeed];
    [self.indicatorView startAnimation:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.view.bounds;
#if TARGET_OS_IPHONE
    rect.origin.y = CGRectGetHeight(rect) - 100;
    rect.size.height = 100;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.height = MIN(screenWidth / 3.0, 210);
#endif
    [hudView setFrame:rect];
    
    hudView.autoresizingMask = NSViewWidthSizable;
    
    self.inputField.stringValue = KTestVideoURL1;
    
    [self setupSamepleRates];
    [self setupSamepleFormats];
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

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate
{
    {
        // ----- Audio Unit Setup -----
#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
    #if TARGET_OS_IPHONE
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
        //int targetSampleRate  = (int)outputFormat.mSampleRate;
        
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
    uint8_t * buffer[2] = { 0 };
    UInt32 bufferSize = 0;
    // 1. 将buffer数组全部置为0；
    for (int i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer audioBuffer = ioData->mBuffers[i];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
        buffer[i] = (uint8_t *)audioBuffer.mData;
        bufferSize = audioBuffer.mDataByteSize;
    }
    
    MRAudioUnitViewController *am = (__bridge MRAudioUnitViewController *)inRefCon;
    [am fillBuffers:buffer byteSize:bufferSize];
    return noErr;
}

- (void)fillBuffers:(uint8_t *[2])buffer
           byteSize:(UInt32)bufferSize
{
    [self.audioFrameQueue fillBuffers:buffer byteSize:bufferSize];
#if DEBUG_RECORD_PCM_TO_FILE
    for(int i = 0; i < 2; i++) {
        uint8_t *src = buffer[i];
        if (NULL != src) {
            if (i == 0) {
                if (file_pcm_l == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"L-%@.pcm",self.audioSampleInfo];
                    const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",l);
                    file_pcm_l = fopen(l, "wb+");
                }
                fwrite(src, bufferSize, 1, file_pcm_l);
            } else if (i == 1) {
                if (file_pcm_r == NULL) {
                    
                    NSString *fileName = [NSString stringWithFormat:@"R-%@.pcm",self.audioSampleInfo];
                    const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",r);
                    file_pcm_r = fopen(r, "wb+");
                }
                fwrite(src, bufferSize, 1, file_pcm_r);
            }
        }
    }
#endif
}

- (void)displayAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSampleInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
    [self.audioFrameQueue enQueue:frame];
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

- (void)doSelectSampleFormat:(MRSampleFormat)targetFmt
{
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

- (void)doSelectSampleRate:(int)sampleRate
{
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

#if TARGET_OS_OSX
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
    [self doSelectSampleFormat:targetFmt];
}

- (IBAction)onSelectSampleRate:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int sampleRate = 0;
    if (item.tag == 1) {
        sampleRate = 44100;
    } else if (item.tag == 2) {
        sampleRate = 48000;
    } else if (item.tag == 3) {
        sampleRate = 96000;
    } else if (item.tag == 4) {
        sampleRate = 192000;
    }
    [self doSelectSampleRate:sampleRate];
}

#else

- (void)setupSamepleFormats
{
#if TARGET_OS_IPHONE
    NSArray *fmts = @[@"S16",@"S16P",@"Float",@"FloatP"];
    NSArray *tags = @[@(MR_SAMPLE_FMT_S16),@(MR_SAMPLE_FMT_S16P),@(MR_SAMPLE_FMT_FLT),@(MR_SAMPLE_FMT_FLTP)];
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
    _audioFmt = [[tags firstObject] intValue];
#else
    _audioFmt = MR_SAMPLE_FMT_S16;
#endif
}

- (void)setupSamepleRates
{
#if TARGET_OS_IPHONE
    NSArray *fmts = @[@"44100",@"48000",@"96000",@"192000"];
    NSArray *tags = @[@(44100),@(48000),@(96000),@(192000)];
    [self.rateSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.rateSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.rateSegCtrl.selectedSegmentIndex = 0;
    _sampleRate = [[tags firstObject] intValue];
#else
    _sampleRate = 44100;
#endif
}

- (IBAction)onSelectAudioFormat:(MRSegmentedControl *)sender
{
    [self doSelectSampleFormat:(MRSampleFormat)[sender tagForCurrentSelected]];
}

- (IBAction)onSelectSampleRate:(MRSegmentedControl *)sender
{
    [self doSelectSampleRate:(int)[sender tagForCurrentSelected]];
}

#endif

@end
