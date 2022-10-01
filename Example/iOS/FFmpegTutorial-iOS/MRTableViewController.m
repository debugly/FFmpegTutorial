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
                @"title":@"0x01",
                @"detail":@"FFmpeg编译配置和版本信息;OpengGL信息",
                @"class":@"MR0x01ViewController",
            },
            @{
                @"title":@"0x02",
                @"detail":@"封装NSThread，方便后续调用",
                @"class":@"MR0x02ViewController",
            },
            @{
                @"title":@"0x03",
                @"detail":@"查看音视频流信息",
                @"class":@"MR0x03ViewController",
            },
            @{
                @"title":@"0x04",
                @"detail":@"读取音视频包",
                @"class":@"MR0x04ViewController",
            },
            @{
                @"title":@"0x05",
                @"detail":@"音视频解码",
                @"class":@"MR0x05ViewController",
            },
            @{
                @"title":@"0x06",
                @"detail":@"抽取解码类，封装解码逻辑",
                @"class":@"MR0x06ViewController",
            }
        ]
    };
    
    NSDictionary *section1 = @{
        @"title":@"二、视频渲染",
        @"cells":@[
            @{
                @"title":@"0x10",
                @"detail":@"封装视频缩放类，方便转出指定的像素格式",
                @"class":@"MR0x10ViewController",
            },
            @{
                @"title":@"0x11",
                @"detail":@"使用 Core Graphics 渲染视频桢",
                @"class":@"MR0x11ViewController",
            },
            @{
                @"title":@"0x12",
                @"detail":@"使用 Core Animation 渲染视频桢",
                @"class":@"MR0x12ViewController",
            },
            @{
                @"title":@"0x13",
                @"detail":@"使用 Core Media 渲染视频桢",
                @"class":@"MR0x13ViewController",
            },
            @{
                @"title":@"0x14",
                @"detail":@"使用 OpenGL 渲染 BGRA 视频桢",
                @"class":@"MR0x14ViewController",
            },
            @{
                @"title":@"0x14-1",
                @"detail":@"抽取 OpenGLCompiler 类，封装 OpenGL Shader 相关逻辑",
                @"class":@"MR0x141ViewController",
            },
            @{
                @"title":@"0x14-2",
                @"detail":@"使用 OpenGL 渲染 NV12 视频桢",
                @"class":@"MR0x142ViewController",
            },
            @{
                @"title":@"0x14-3",
                @"detail":@"使用 OpenGL 渲染 NV21 视频桢",
                @"class":@"MR0x143ViewController",
            },
            @{
                @"title":@"0x14-4",
                @"detail":@"使用 OpenGL 渲染 YUV420P 视频桢",
                @"class":@"MR0x144ViewController",
            },
            @{
                @"title":@"0x15-1",
                @"detail":@"使用 OpenGL ES3 渲染 NV12 视频桢",
                @"class":@"MR0x151ViewController",
            },
            @{
                @"title":@"0x15-2",
                @"detail":@"使用 OpenGL ES3 渲染 YUV420P 视频桢",
                @"class":@"MR0x152ViewController",
            },
            @{
                @"title":@"0x15-5",
                @"detail":@"使用 OpenGL ES3 渲染 NV21 视频桢",
                @"class":@"MR0x155ViewController",
            },
            @{
                @"title":@"0x15-6",
                @"detail":@"使用 OpenGL ES3 渲染 BGRA 视频桢",
                @"class":@"MR0x156ViewController",
            },
            @{
                @"title":@"0x16",
                @"detail":@"使用 FBO 离屏渲染截图",
                @"class":@"MR0x16ViewController",
            },
            @{
                @"title":@"0x17",
                @"detail":@"TODO:使用 Metal 渲染视频桢",
                @"class":@"",
            }
        ]
    };
    
    NSDictionary *section2 = @{
        @"title":@"三、音频渲染",
        @"cells":@[
            @{
                @"title":@"0x20",
                @"detail":@"封装音频重采样类，方便转出指定的采样格式",
                @"class":@"MR0x20ViewController",
            },
            @{
                @"title":@"0x21",
                @"detail":@"使用 AudioUnit 渲染音频桢，断断续续的",
                @"class":@"MR0x21ViewController",
            },
            @{
                @"title":@"0x22",
                @"detail":@"增加Frame缓存队列，解决断断续续问题",
                @"class":@"MR0x22ViewController",
            },
            @{
                @"title":@"0x23",
                @"detail":@"使用 AudioQueue 渲染音频桢",
                @"class":@"MR0x23ViewController",
            },
            @{
                @"title":@"0x24",
                @"detail":@"抽取 AudioRenderer 类，封装底层音频渲染逻辑",
                @"class":@"MR0x24ViewController",
            }
        ]
    };
    
    NSDictionary *section3 = @{
        @"title":@"四、封装播放器",
        @"cells":@[
            @{
                @"title":@"0x30",
                @"detail":@"增加 VideoFrame 缓存队列，不再阻塞解码线程",
                @"class":@"MR0x30ViewController",
            },
            @{
                @"title":@"0x31",
                @"detail":@"增加 AVPacket 缓存队列，创建解码线程",
                @"class":@"MR0x31ViewController",
            },
            @{
                @"title":@"0x32",
                @"detail":@"创建视频渲染线程，将视频相关逻辑封装到播放器内",
                @"class":@"MR0x32ViewController",
            },
            @{
                @"title":@"0x33",
                @"detail":@"将音频相关逻辑封装到播放器内",
                @"class":@"MR0x33ViewController",
            },
            @{
                @"title":@"0x34",
                @"detail":@"显示音视频播放进度",
                @"class":@"MR0x34ViewController",
            },
            @{
                @"title":@"0x35",
                @"detail":@"音视频同步",
                @"class":@"MR0x35ViewController",
            },
            @{
                @"title":@"0x36",
                @"detail":@"开始，结束，暂停，续播",
                @"class":@"MR0x36ViewController",
            },
            @{
                @"title":@"0x37",
                @"detail":@"支持Seek",
                @"class":@"MR0x37ViewController",
            },
            @{
                @"title":@"0x38",
                @"detail":@"支持指定播放开始位置",
                @"class":@"MR0x38ViewController",
            },
            @{
                @"title":@"0x39",
                @"detail":@"使用硬件加速解码",
                @"class":@"MR0x39ViewController",
            },
            @{
                @"title":@"0x3a",
                @"detail":@"统一软硬解解码数据结构",
                @"class":@"MR0x3aViewController",
            },
            @{
                @"title":@"0x3b",
                @"detail":@"统一软硬解渲染逻辑",
                @"class":@"MR0x3bViewController",
            },
            @{
                @"title":@"0x40",
                @"detail":@"iOS和Mac公用一套渲染逻辑",
                @"class":@"MR0x40ViewController",
            }
        ]
    };
    
    NSDictionary *section4 = @{
        @"title":@"五、趣味实验",
        @"cells":@[
            @{
                @"title":@"0x50",
                @"detail":@"雪花屏，灰色色阶图，三个小球",
                @"class":@"MR0x50ViewController",
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
    return NO;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
    return UIInterfaceOrientationPortrait;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
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
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    } else {
        NSString * url = dic[@"url"];
        if (url) {
            //
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
