//
//  MR0x10ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/11.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x10ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <MRFFmpegPod/libavutil/frame.h>

@interface MR0x10ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *input;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (weak, nonatomic) IBOutlet UILabel *audioPktLb;
@property (weak, nonatomic) IBOutlet UILabel *vidoePktLb;
@property (weak, nonatomic) IBOutlet UILabel *audioFrameLb;
@property (weak, nonatomic) IBOutlet UILabel *videoFrameLb;
@property (weak, nonatomic) IBOutlet UILabel *infoLb;

@property (strong) FFTPlayer0x10 *player;

@end

@implementation MR0x10ViewController

- (void)resetUI {
    self.audioPktLb.text = nil;
    self.vidoePktLb.text = nil;
    self.audioFrameLb.text = nil;
    self.videoFrameLb.text = nil;
    self.infoLb.text = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.input.text = KTestVideoURL1;
    [self resetUI];
}

- (void)parseURL:(NSString *)url
{
    [self.indicator startAnimating];
    if (self.player) {
        [self.player asyncStop];
    }
    
    FFTPlayer0x10 *player = [[FFTPlayer0x10 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormats = MR_PIX_FMT_MASK_RGBA;// |
    //    MR_PIX_FMT_MASK_NV12 |
    //    MR_PIX_FMT_MASK_BGRA;
    
    __weakSelf__
    player.onError = ^(NSError *err){
        NSLog(@"%@",err);
        __strongSelf__
        mr_async_main_queue(^{
            [self.indicator stopAnimating];
            self.player = nil;
        });
    };
    
    player.onReadPkt = ^(int a,int v){
        __strongSelf__
        mr_async_main_queue(^{
            self.audioPktLb.text = [NSString stringWithFormat:@"%d",a];
            self.vidoePktLb.text = [NSString stringWithFormat:@"%d",v];
        });
    };
    
    player.onDecoderFrame = ^(int type,int serial,AVFrame *frame) {
        __strongSelf__
        mr_async_main_queue(^{
            //video
            if (type == 1) {
                self.videoFrameLb.text = [NSString stringWithFormat:@"%d",serial];
                self.infoLb.text = [NSString stringWithFormat:@"%d,%lld",frame->format,frame->pts];
            }
            //audio
            else if (type == 2) {
                self.audioFrameLb.text = [NSString stringWithFormat:@"%d",serial];
            }
        });
    };

    [player prepareToPlay];
    [player play];
    self.player = player;
}

- (IBAction)go:(UIButton *)sender {
    
    if (self.input.text.length > 0) {
        [self resetUI];
        [self parseURL:self.input.text];
    }
}

@end
