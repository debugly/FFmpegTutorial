//
//  MR0x03ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/4/27.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x03ViewController.h"
#import <FFmpegTutorial/FFPlayer0x03.h>

@interface MR0x03ViewController ()

@property (nonatomic, strong) FFPlayer0x03 *player;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@end

@implementation MR0x03ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    FFPlayer0x03 *player = [[FFPlayer0x03 alloc] init];
    player.contentPath = @"http://data.vod.itc.cn/?new=/73/15/oFed4wzSTZe8HPqHZ8aF7J.mp4&vid=77972299&plat=14&mkey=XhSpuZUl_JtNVIuSKCB05MuFBiqUP7rB&ch=null&user=api&qd=8001&cv=3.13&uid=F45C89AE5BC3&ca=2&pg=5&pt=1&prod=ifox";
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimating];
        self.textView.text = [self.player.error localizedDescription];
        self.player = nil;
    }];
    
    [player prepareToPlay];
    [player readPacket];
    self.player = player;
}

@end
