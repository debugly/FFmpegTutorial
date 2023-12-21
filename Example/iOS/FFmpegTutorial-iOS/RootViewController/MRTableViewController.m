//
//  MRTableViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/4/19.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRTableViewController.h"

@interface MRTableViewController ()

@property(nonatomic, strong) NSArray <NSDictionary *>*dataArr;

@end

@implementation MRTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    NSDictionary *section0 = @{
        @"title":@"一、音视频基础",
        @"cells":@[
            @{
                @"title":@"OpenGL Version",
                @"detail":@"FFmpeg编译配置和版本信息;OpengGL信息",
                @"class":@"MRGLVersionViewController",
            },
            @{
                @"title":@"Custom Thread",
                @"detail":@"封装NSThread，方便后续调用",
                @"class":@"MRCustomThreadViewController",
            },
            @{
                @"title":@"Movie Prober",
                @"detail":@"查看音视频流信息",
                @"class":@"MRMovieProberViewController",
            },
            @{
                @"title":@"Read Packet",
                @"detail":@"读取音视频包",
                @"class":@"MRReadPacketViewController",
            },
            @{
                @"title":@"Decode Packet",
                @"detail":@"音视频解码",
                @"class":@"MRDecodePacketViewController",
            },
            @{
                @"title":@"Custom Decoder",
                @"detail":@"抽取解码类，封装解码逻辑",
                @"class":@"MRCustomDecoderViewController",
            }
        ]
    };
    
    NSDictionary *section1 = @{
        @"title":@"二、视频渲染",
        @"cells":@[
            @{
                @"title":@"Core Animation/Core Graphics/Core Media",
                @"detail":@"渲染 BGRx/RGBx/NV12/YUYV/UYVY 视频桢",
                @"class":@"MRGAMViewController",
            },
            @{
                @"title":@"OpenGL ES2",
                @"detail":@"渲染 BGRx/RGBx/NV12/NV21/YUV420P 视频桢",
                @"class":@"MRGLES2ViewController",
            },
            @{
                @"title":@"OpenGL ES3",
                @"detail":@"渲染 BGRx/RGBx/NV12/NV21/YUV420P 视频桢",
                @"class":@"MRGLES3ViewController",
            },
            @{
                @"title":@"Metal",
                @"detail":@"渲染 BGRA/NV12/NV21/YUV420P/UYVY/YUYV 视频桢",
                @"class":@"MRMetalViewController",
            }
        ]
    };
    
    NSDictionary *section2 = @{
        @"title":@"三、音频渲染",
        @"cells":@[
            @{
                @"title":@"AudioUnit",
                @"detail":@"支持 S16,S16P,Float,FloatP 格式，采样率为 44.1K,48K,96K,192K",
                @"class":@"MRAudioUnitViewController",
            },
            @{
                @"title":@"AudioQueue",
                @"detail":@"支持 S16,Float 格式，采样率为 44.1K,48K,96K,192K",
                @"class":@"MRAudioQueueViewController",
            },
            @{
                @"title":@"封装AudioUnit 和 AudioQueue",
                @"detail":@"支持 S16,S16P,Float,FloatP 格式，采样率为 44.1K,48K,96K,192K",
                @"class":@"MRAudioRendererViewController",
            }
        ]
    };
    
    NSDictionary *section3 = @{
        @"title":@"四、封装播放器",
        @"cells":@[
            @{
                @"title":@"VideoFrameQueue",
                @"detail":@"增加 VideoFrame 缓存队列，不再阻塞解码线程",
                @"class":@"MRVideoFrameQueueViewController",
            },
            @{
                @"title":@"PacketQueue",
                @"detail":@"增加 AVPacket 缓存队列，创建解码线程",
                @"class":@"MRPacketQueueViewController",
            },
            @{
                @"title":@"VideoRendering Embed",
                @"detail":@"创建视频渲染线程，将视频相关逻辑封装到播放器内",
                @"class":@"MRVideoEmbedViewController",
            },
            @{
                @"title":@"AudioRendering Embed",
                @"detail":@"将音频相关逻辑封装到播放器内",
                @"class":@"MRAudioEmbedViewController",
            },
            @{
                @"title":@"Show Play Progress",
                @"detail":@"显示音视频播放进度",
                @"class":@"MRPlayProgressViewController",
            },
            @{
                @"title":@"Sync Audio And Video",
                @"detail":@"音视频同步",
                @"class":@"MRSyncAVViewController",
            }
        ]
    };
    
    NSDictionary *section4 = @{
        @"title":@"五、趣味实验",
        @"cells":@[
            @{
                @"title":@"Have Fun",
                @"detail":@"雪花屏，灰色色阶图，三个小球",
                @"class":@"MRHaveFunViewController",
            }
        ]
    };
    
    NSDictionary *section5 = @{
        @"title":@"六、实用工具",
        @"cells":@[
            @{
                @"title":@"VTP",
                @"detail":@"高效视频抽帧器",
                @"url":@"https://github.com/debugly/MRVideoToPicture"
            }
        ]
    };
    
    self.dataArr = @[section0,section1,section2,section3,section4,section5];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeLeft;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 45;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.dataArr count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSDictionary *dic = self.dataArr[section];
    NSArray *cells = dic[@"cells"];
    return [cells count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSDictionary *dic = self.dataArr[section];
    return dic[@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSDictionary *dic = self.dataArr[indexPath.section];
    NSArray *cells = dic[@"cells"];
    NSDictionary *info = cells[indexPath.row];
    cell.textLabel.text = info[@"title"];
    cell.detailTextLabel.text = info[@"detail"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dic = self.dataArr[indexPath.section];
    NSArray *cells = dic[@"cells"];
    NSDictionary *info = cells[indexPath.row];
    NSString *cls = info[@"class"];
    if (cls) {
        Class clazz = NSClassFromString(cls);
        if (clazz) {
            UIViewController *vc = [[clazz alloc] initWithNibName:cls bundle:nil];
            vc.title = dic[@"detail"];
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            
        }
    } else {
        NSString * url = info[@"url"];
        if (url) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:NULL];
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
