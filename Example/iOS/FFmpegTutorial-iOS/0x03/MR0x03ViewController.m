//
//  MR0x03ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/9.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x03ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x02.h>

@interface MR0x03ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *input;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;

@property (strong) FFTPlayer0x02 *player;

@end

@implementation MR0x03ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.input.text = KTestVideoURL1;
}

- (void)parseURL:(NSString *)url
{
    [self.indicator startAnimating];
    if (self.player) {
        [self.player asyncStop];
    }
    
    FFTPlayer0x02 *player = [[FFTPlayer0x02 alloc] init];
    player.contentPath = url;
    [player prepareToPlay];
    __weakSelf__
    [player openStream:^(NSError * _Nullable error, NSString * _Nullable info) {
        __strongSelf__
        [self.indicator stopAnimating];
        if (error) {
            self.textView.text = [error localizedDescription];
        } else {
            self.textView.text = info;
        }
        [self.player asyncStop];
        self.player = nil;
    }];
    
    self.player = player;
}

- (IBAction)go:(UIButton *)sender {
    
    if (self.input.text.length > 0) {
        self.textView.text = @"...";
        [self parseURL:self.input.text];
    }
}

@end
