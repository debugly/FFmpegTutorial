//
//  MR0x02ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 09/09/2022.
//  Copyright (c) 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x02ViewController.h"
#import <FFmpegTutorial/FFTThread.h>

@interface MR0x02ViewController ()
{
    NSMutableArray* _msg_buff;
}

@property (assign) IBOutlet UITextView *textView;
@property (strong) NSMutableArray *array;
@property (strong) NSLock *lock;

@end

@implementation MR0x02ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.lock = [[NSLock alloc] init];
    _msg_buff = [NSMutableArray array];
    
    UIBarButtonItem *go = [[UIBarButtonItem alloc] initWithTitle:@"go" style:UIBarButtonItemStylePlain target:self action:@selector(go:)];
    self.navigationItem.rightBarButtonItem = go;
}

- (void)doCancel:(NSMutableArray *)arr
{
    if ([arr count] == 0) {
        return;
    }
    FFTThread *t = [arr lastObject];;
    [t cancel];
    [t join];
    [arr removeLastObject];
    double delay = arc4random() % 1000 / 10000.0;
    [self performSelector:@selector(doCancel:) withObject:arr afterDelay:delay];
    
    NSString *msg = nil;
    [self.lock lock];
    msg = [_msg_buff componentsJoinedByString:@"\n"];
    [self.lock unlock];
    self.textView.text = msg;
}

- (void)appendMsg:(NSString *)msg
{
    [self.lock lock];
    if ([_msg_buff count] > 25) {
        [_msg_buff removeObjectAtIndex:0];
    }
    [_msg_buff addObject:msg];
    [self.lock unlock];
}

- (IBAction)go:(UIButton *)sender
{
    NSMutableArray *arr = [NSMutableArray array];
    static int count = 0;
    for (int i = 0; i < 100; i++) {
        int n = count++;
        FFTThread *t = [[FFTThread alloc] initWithBlock:^{
            while (![[NSThread currentThread] isCancelled]) {
                int s = 1 + arc4random() % 10;
                usleep(1000 * s);
                NSString *msg = [NSString stringWithFormat:@"%@ sleep %d ms",[[NSThread currentThread]name],s];
                [self appendMsg:msg];
            }
        }];
        t.name = [NSString stringWithFormat:@"%d",n];
        [arr addObject:t];
        [t start];
    }
    [self performSelector:@selector(doCancel:) withObject:arr afterDelay:0.05];
}

@end
