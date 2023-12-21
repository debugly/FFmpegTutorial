//
//  MRMovieProberViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMovieProberViewController.h"
#import <FFmpegTutorial/FFTPlayer0x02.h>
#if TARGET_OS_OSX
#import "MRDragView.h"
#import "MRUtil.h"
#endif

@interface MRMovieProberViewController ()
#if TARGET_OS_OSX
<MRDragViewDelegate>
#endif

@property (strong) FFTPlayer0x02 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (assign) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (strong) NSArray <NSURL *>* urlArr;

@end

@implementation MRMovieProberViewController

- (void)dealloc
{
}

- (IBAction)go:(NSButton *)sender
{
#if TARGET_OS_OSX
    [self fetchFirstURL];
#endif
    if (self.inputField.stringValue.length > 0) {
        [self parseURL:self.inputField.stringValue];
    } else {
        self.inputField.placeholderString = @"请输入视频地址";
    }
#if TARGET_OS_IPHONE
    [self.inputField resignFirstResponder];
#endif
}

- (void)parseURL:(NSString *)url
{
    [self.indicatorView startAnimation:nil];
    if (self.player) {
        [self.player asyncStop];
    }
    
    FFTPlayer0x02 *player = [[FFTPlayer0x02 alloc] init];
    player.contentPath = url;
    [player prepareToPlay];
    __weakSelf__
    [player openStream:^(NSError * _Nullable error, NSString * _Nullable info) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        if (error) {
            self.textView.string = [error localizedDescription];
        } else {
            self.textView.string = info;
        }
        [self.player asyncStop];
        self.player = nil;
    }];
    
    self.player = player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
#if TARGET_OS_OSX
    self.textView.string = @"可拖拽视频文件查看视频信息";
#endif
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
}

#if TARGET_OS_OSX
#pragma mark --拖拽的代理方法

- (NSDragOperation)acceptDragOperation:(NSArray<NSURL *> *)list
{
    for (NSURL *url in list) {
        if (url) {
            //先判断是不是文件夹
            BOOL isDirectory = NO;
            BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
            if (isExist) {
                if (isDirectory) {
                   //扫描文件夹
                   NSString *dir = [url path];
                   NSArray *dicArr = [MRUtil scanFolderWithPath:dir filter:[MRUtil videoType]];
                    if ([dicArr count] > 0) {
                        return NSDragOperationCopy;
                    }
                } else {
                    NSString *pathExtension = [[url pathExtension] lowercaseString];
                    if ([[MRUtil videoType] containsObject:pathExtension]) {
                        return NSDragOperationCopy;
                    }
                }
            }
        }
    }
    return NSDragOperationNone;
}

- (void)fetchFirstURL
{
    NSString *path = nil;
    NSMutableArray *urlArr = [NSMutableArray arrayWithArray:self.urlArr];
    NSURL *url = [urlArr firstObject];
    if ([url isFileURL]) {
        path = [url path];
    } else {
        path = [url absoluteString];
    }
    if ([urlArr count] > 0) {
        [urlArr removeObjectAtIndex:0];
    }
    self.urlArr = [urlArr copy];
    
    if (path) {
        self.inputField.stringValue = path;
    }
}

- (void)handleDragFileList:(NSArray <NSURL *> *)fileUrls
{
    NSMutableArray *bookmarkArr = [NSMutableArray array];

    for (NSURL *url in fileUrls) {
        //先判断是不是文件夹
        BOOL isDirectory = NO;
        BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
        if (isExist) {
            if (isDirectory) {
                //扫描文件夹
                NSString *dir = [url path];
                NSArray *dicArr = [MRUtil scanFolderWithPath:dir filter:[MRUtil videoType]];
                if ([dicArr count] > 0) {
                    [bookmarkArr addObjectsFromArray:dicArr];
                }
            } else {
                NSString *pathExtension = [[url pathExtension] lowercaseString];
                if ([[MRUtil videoType] containsObject:pathExtension]) {
                    //视频
                    NSDictionary *dic = [MRUtil makeBookmarkWithURL:url];
                    [bookmarkArr addObject:dic];
                }
            }
        }
    }
    
    NSMutableArray *urls = [NSMutableArray array];
    
    for (int i = 0; i < [bookmarkArr count]; i++) {
        NSDictionary *info = bookmarkArr[i];
        NSURL *url = info[@"url"];
        //NSData *bookmark = info[@"bookmark"];
        if (url) {
            [urls addObject:url];
        }
    }
    
    NSMutableArray *urlArr = [NSMutableArray arrayWithArray:self.urlArr];
    [urlArr addObjectsFromArray:urls];
    self.urlArr = [urlArr copy];
    
    [self go:nil];
}
#endif

@end
