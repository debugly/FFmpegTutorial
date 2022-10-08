//
//  MR0x05ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/11.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x05ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x05.h>
#import <FFmpegTutorial/FFTDispatch.h>

@interface MR0x05ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *input;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (weak, nonatomic) IBOutlet UILabel *audioPktLb;
@property (weak, nonatomic) IBOutlet UILabel *vidoePktLb;
@property (weak, nonatomic) IBOutlet UILabel *audioFrameLb;
@property (weak, nonatomic) IBOutlet UILabel *videoFrameLb;

@property (strong) FFTPlayer0x05 *player;

@end

@implementation MR0x05ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.input.text = KTestVideoURL1;
    self.audioPktLb.text = nil;
    self.vidoePktLb.text = nil;
    self.audioFrameLb.text = nil;
    self.videoFrameLb.text = nil;
}

- (void)parseURL:(NSString *)url
{
    [self.indicator startAnimating];
    if (self.player) {
        [self.player asyncStop];
    }
    
    FFTPlayer0x05 *player = [[FFTPlayer0x05 alloc] init];
    player.contentPath = url;
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        mr_async_main_queue(^{
            [self.indicator stopAnimating];
            self.player = nil;
        });
    }];
    
    player.onReadPkt = ^(int a,int v){
        __strongSelf__
        mr_async_main_queue(^{
            self.audioPktLb.text = [NSString stringWithFormat:@"%d",a];
            self.vidoePktLb.text = [NSString stringWithFormat:@"%d",v];
        });
    };
    
    player.onDecoderFrame = ^(int a, int v) {
        __strongSelf__
        mr_async_main_queue(^{
            self.audioFrameLb.text = [NSString stringWithFormat:@"%d",a];
            self.videoFrameLb.text = [NSString stringWithFormat:@"%d",v];
            [self.indicator stopAnimating];
        });
    };

    [player prepareToPlay];
    [player play];
    self.player = player;
}

- (IBAction)go:(UIButton *)sender {
    
    if (self.input.text.length > 0) {
        self.audioPktLb.text = nil;
        self.vidoePktLb.text = nil;
        self.audioFrameLb.text = nil;
        self.videoFrameLb.text = nil;
        [self parseURL:self.input.text];
    }
}

@end
