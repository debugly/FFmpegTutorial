//
//  MR0x20ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/21.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x20ViewController.h"
#import <FFmpegTutorial/FFPlayer0x20.h>
#import "MRRWeakProxy.h"
#import "MR0x20VideoRenderer.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0


@interface MR0x20ViewController ()<FFPlayer0x20Delegate>

{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (assign) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x20VideoRenderer *videoRenderer;

@property (assign) NSInteger ignoreScrollBottom;
@property (weak) NSTimer *timer;
@property (assign) BOOL scrolling;
@property (assign) MR_PACKET_SIZE pktSize;

//声音大小
@property (nonatomic,assign) float outputVolume;
//最终音频格式（采样深度）
@property (nonatomic,assign) MRSampleFormat finalSampleFmt;
//音频渲染
@property (nonatomic,assign) AudioUnit audioUnit;
//采样率
@property (nonatomic,assign) int targetSampleRate;


@end

@implementation MR0x20ViewController

- (void)_stop
{
    if (_audioUnit) {
        AudioOutputUnitStop(_audioUnit);
        _audioUnit = NULL;
    }
    
#if DEBUG_RECORD_PCM_TO_FILE
    fclose(file_pcm_l);
    fclose(file_pcm_r);
#endif
    
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player stop];
        _player = nil;
    }
}

- (void)dealloc
{
    [self _stop];
    
    _textView.delegate = nil;
    _textView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appendMsg:(NSString *)txt
{
    self.textView.string = [self.textView.string stringByAppendingFormat:@"\n%@",txt];
    if (self.scrolling) {
        return;
    }
    [self.textView scrollToEndOfDocument:nil];
}

- (void)prepareTickTimerIfNeed
{
    if (self.timer && ![self.timer isValid]) {
        return;
    }
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
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
            OSStatus status = AudioOutputUnitStart(self.audioUnit);
            NSAssert(noErr == status, @"AudioOutputUnitStart");
            started = true;
        }
    });
}

- (void)onInitAudioRender:(MRSampleFormat)fmt
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupAudioRender:fmt];
    });
}

- (void)setupAudioRender:(MRSampleFormat)fmt
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
        outputFormat.mSampleRate = _targetSampleRate;
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
        
        self.finalSampleFmt = fmt;
    }
}

#pragma mark - 音频

//音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    MR0x20ViewController *am = (__bridge MR0x20ViewController *)inRefCon;
    return [am renderFrames:inNumberFrames ioData:ioData];
}

- (bool)renderFrames:(UInt32) wantFrames
              ioData:(AudioBufferList *) ioData
{
    // 1. 将buffer数组全部置为0；
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        AudioBuffer audioBuffer = ioData->mBuffers[iBuffer];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
    }
    
    //目标是Packet类型
    if(MR_Sample_Fmt_Is_Packet(self.finalSampleFmt)){
    
        //    numFrames = 1115
        //    SInt16 = 2;
        //    mNumberChannels = 2;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 4460
        // 4460 = numFrames x SInt16 * mNumberChannels = 1115 x 2 x 2;
        
        // 2. 获取 AudioUnit 的 Buffer
        int numberBuffers = ioData->mNumberBuffers;
        
        // AudioUnit 对于 packet 形式的PCM，只会提供一个 AudioBuffer
        if (numberBuffers >= 1) {
            
            AudioBuffer audioBuffer = ioData->mBuffers[0];
            //这个是 AudioUnit 给我们提供的用于存放采样点的buffer
            uint8_t *buffer = audioBuffer.mData;
            // 长度可以这么计算，也可以使用 audioBuffer.mDataByteSize 获取
            //                //每个采样点占用的字节数:
            //                UInt32 bytesPrePack = self.outputFormat.mBitsPerChannel / 8;
            //                //Audio的Frame是包括所有声道的，所以要乘以声道数；
            //                const NSUInteger frameSizeOf = 2 * bytesPrePack;
            //                //向缓存的音频帧索要wantBytes个音频采样点: wantFrames x frameSizeOf
            //                NSUInteger bufferSize = wantFrames * frameSizeOf;
            const UInt32 bufferSize = audioBuffer.mDataByteSize;
            /* 对于 AV_SAMPLE_FMT_S16 而言，采样点是这么分布的:
             S16_L,S16_R,S16_L,S16_R,……
             AudioBuffer 也需要这样的排列格式，因此直接copy即可；
             同理，对于 FLOAT 也是如此左右交替！
             */
            
            //3. 获取 bufferSize 个字节，并塞到 buffer 里；
            [self fetchPacketSample:buffer wantBytes:bufferSize];
        } else {
            NSLog(@"what's wrong?");
        }
    }
    
    //目标是Planar类型，Mac平台支持整形和浮点型，交错和二维平面
    
    else if (MR_Sample_Fmt_Is_Planar(self.finalSampleFmt)){
        
        //    numFrames = 558
        //    float = 4;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 2232
        // 2232 = numFrames x float = 558 x 4;
        // FLTP = FLOAT + Planar;
        // FLOAT: 具体含义是使用 float 类型存储量化的采样点，比 SInt16 精度要高出很多！当然空间也大些！
        // Planar: 二维的，所以会把左右声道使用两个数组分开存储，每个数组里的元素是同一个声道的！
        
        //when outputFormat.mChannelsPerFrame == 2
        if (ioData->mNumberBuffers == 2) {
            // 2. 向缓存的音频帧索要 ioData->mBuffers[0].mDataByteSize 个字节的数据
            /*
             Float_L,Float_L,Float_L,Float_L,……  -> mBuffers[0].mData
             Float_R,Float_R,Float_R,Float_R,……  -> mBuffers[1].mData
             左对左，右对右
             
             同理，对于 S16P 也是如此！一一对应！
             */
            //3. 获取左右声道数据
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:ioData->mBuffers[1].mData rightSize:ioData->mBuffers[1].mDataByteSize];
        }
        //when outputFormat.mChannelsPerFrame == 1;不会左右分开
        else {
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:NULL rightSize:0];
        }
    }
    return noErr;
}

- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
    
    #if DEBUG_RECORD_PCM_TO_FILE
    fwrite(buffer, 1, filled, self->file_pcm_l);
    #endif
    return filled;
}

- (UInt32)fetchPlanarSample:(uint8_t*)left
                  leftSize:(UInt32)leftSize
                     right:(uint8_t*)right
                 rightSize:(UInt32)rightSize
{
    UInt32 filled = [self.player fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
    #if DEBUG_RECORD_PCM_TO_FILE
    fwrite(left, 1, leftSize, self->file_pcm_l);
    fwrite(right, 1, rightSize, self->file_pcm_r);
    
    fflush(self->file_pcm_l);
    fflush(self->file_pcm_r);
    #endif
    return filled;
}

- (void)onTimer:(NSTimer *)sender
{
    MR_PACKET_SIZE pktSize = [self.player peekPacketBufferStatus];
    if (0 == mr_packet_size_equal(self.pktSize, pktSize)) {
        return;
    }
    
    [self.indicatorView stopAnimation:nil];
    
    NSString *frmMsg = [NSString stringWithFormat:@"[Frame] audio(%002d)，video(%002d)",self.player.audioFrameCount,self.player.videoFrameCount];
    
    NSString *pktMsg = nil;
    if (mr_packet_size_equal_zero(pktSize)) {
        pktMsg = @"Packet Buffer is Empty";
    } else {
        pktMsg = [NSString stringWithFormat:@" [Packet] audio(%02d)，video(%02d)",pktSize.audio_pkt_size,pktSize.video_pkt_size];
    }
    self.pktSize = pktSize;
    [self appendMsg:[frmMsg stringByAppendingString:pktMsg]];
}

- (void)parseURL:(NSString *)url
{
    [self _stop];
    self.textView.string = @"";
    
    FFPlayer0x20 *player = [[FFPlayer0x20 alloc] init];
    player.contentPath = url;
    
    [self.indicatorView startAnimation:nil];
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        self.textView.string = [self.player.error localizedDescription];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats = MR_PIX_FMT_MASK_NV21;
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_AUTO;
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willStartScroll:) name:NSScrollViewWillStartLiveScrollNotification object:self.textView.enclosingScrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEndScroll:) name:NSScrollViewDidEndLiveScrollNotification object:self.textView.enclosingScrollView];
    [self.videoRenderer setWantsLayer:YES];
    self.videoRenderer.layer.backgroundColor = [[NSColor redColor]CGColor];
    
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
    
    if (file_pcm_r == NULL) {
        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"R.pcm"]UTF8String];
        file_pcm_r = fopen(r, "wb+");
    }
#endif
}

- (void)willStartScroll:(NSScrollView *)sender
{
    self.scrolling = YES;
}

- (void)didEndScroll:(NSScrollView *)sender
{
    if ([self.timer isValid]) {
        [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    self.scrolling = NO;
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
