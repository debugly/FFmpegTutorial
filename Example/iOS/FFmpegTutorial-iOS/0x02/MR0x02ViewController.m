//
//  MR0x02ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/4/25.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x02ViewController.h"
#import <FFmpegTutorial/FFPlayer0x02.h>

@interface MR0x02ViewController ()

@property (nonatomic, strong) FFPlayer0x02 *player;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@end

@implementation MR0x02ViewController

- (void)dealloc
{
    if (self.player) {
        [self.player stop];
        self.player = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    FFPlayer0x02 *player = [[FFPlayer0x02 alloc] init];
    player.contentPath = @"http://data.vod.itc.cn/?new=/73/15/oFed4wzSTZe8HPqHZ8aF7J.mp4&vid=77972299&plat=14&mkey=XhSpuZUl_JtNVIuSKCB05MuFBiqUP7rB&ch=null&user=api&qd=8001&cv=3.13&uid=F45C89AE5BC3&ca=2&pg=5&pt=1&prod=ifox";
    [player prepareToPlay];
    __weakSelf__
    [player openStream:^(NSError * _Nullable error, NSString * _Nullable info) {
        __strongSelf__
        [self.indicatorView stopAnimating];
        if (error) {
            self.textView.text = [error localizedDescription];
        } else {
            self.textView.text = info;
        }
        self.player = nil;
    }];
    
    self.player = player;
}

@end
