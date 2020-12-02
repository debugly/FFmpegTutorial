//
//  MR0x40ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by Matt Reach on 2020/11/18.
//

#import "MR0x40ViewController.h"
#import "MRDragView.h"
#import "MRUtil.h"
#import "MR0x40Task.h"

#ifndef __MRWS__
#define __MRWS__

#ifndef __weakSelf__
#define __weakSelf__  __weak    typeof(self)weakSelf = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__ __strong typeof(weakSelf)self = weakSelf;
#endif

#define __weakObj(obj)   __weak   typeof(obj)weak##obj = obj;
#define __strongObj(obj) __strong typeof(weak##obj)obj = weak##obj;

#endif

@interface MR0x40ViewController ()<MRDragViewDelegate>

@property (weak) IBOutlet MRDragView *dragView;
@property (strong) NSMutableArray *taskArr;

@end

@implementation MR0x40ViewController

//-[NSNib _initWithNibNamed:bundle:options:] could not load the nibName: MR0x40ViewController in bundle (null).
//- (void)loadView
//{
//    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
//}

- (void)handleDragFileList:(nonnull NSArray<NSURL *> *)fileUrls
{
    NSMutableArray *bookmarkArr = [NSMutableArray array];
    for (NSURL *url in fileUrls) {
        //先判断是不是文件夹
        BOOL isDirectory = NO;
        BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
        if (isExist) {
            if (isDirectory) {
                ///扫描文件夹
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
    
    if ([bookmarkArr count] > 0) {
        for (NSDictionary *dic in bookmarkArr) {
            NSURL *url = dic[@"url"];
            MR0x40Task *task = [[MR0x40Task alloc] initWithURL:url];
            if (!self.taskArr) {
                self.taskArr = [NSMutableArray array];
            }
            [self.taskArr addObject:task];
            [task start:^{
                NSLog(@"%@:%0.2fs,%d,%0.2ffpms;%@",task.videoName,task.cost,task.frameCount,1000 * task.cost/task.frameCount,task.picSaveDir);
            }];
        }
    }
}

- (NSDragOperation)acceptDragOperation:(NSArray<NSURL *> *)list
{
    for (NSURL *url in list) {
        if (url) {
            //先判断是不是文件夹
            BOOL isDirectory = NO;
            BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
            if (isExist) {
                if (isDirectory) {
                   ///扫描文件夹
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

@end
