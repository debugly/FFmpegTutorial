//
//  RootViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/25.
//

#import "RootViewController.h"
#import "RootTableRowView.h"
#import "NSNavigationController.h"

@interface RootViewController ()<NSTableViewDelegate,NSTableViewDataSource>

@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSArray *dataArr;

@end

@implementation RootViewController

//-[NSNib _initWithNibNamed:bundle:options:] could not load the nibName: RootViewController in bundle (null).
- (void)loadView
{
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    self.title = @"FFmpeg-Tutorial";
    
    NSScrollView * scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = NO;
    scrollView.hasHorizontalScroller = NO;
    scrollView.frame = self.view.bounds;
    scrollView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    [self.view addSubview:scrollView];
    
    NSTableView *tableView = [[NSTableView alloc] initWithFrame:self.view.bounds];
    tableView.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    tableView.intercellSpacing = NSMakeSize(0, 0);
//    if (@available(macOS 11.0, *)) {
//        tableView.style = NSTableViewStylePlain;
//    } else {
//        // Fallback on earlier versions
//    }
    //设置选中行背景样式，设置成None时drawSelectionInRect就不走了;
    tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
//    NSTableColumn *column = [[NSTableColumn alloc] init];
//    column.title = @"我的FFmpeg学习教程";
//    column.editable = NO;
//    column.width = CGRectGetWidth(self.view.bounds);
//    column.resizingMask = NSTableColumnAutoresizingMask;
//    [tableView addTableColumn:column];
    //隐藏掉列Header
    tableView.headerView = nil;
    //开启后，不能覆盖drawBackgroundInRect否则无效
    tableView.usesAlternatingRowBackgroundColors = NO;
    //横实线
    //tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    //tableView.gridStyleMask = NSTableViewSolidVerticalGridLineMask;

    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowSizeStyle = NSTableViewRowSizeStyleCustom;
    scrollView.contentView.documentView = tableView;
    scrollView.contentInsets = NSEdgeInsetsZero;
    scrollView.scrollerInsets = NSEdgeInsetsZero;
    
    self.dataArr = @[
        @{
            @"title":@"一、音视频基础",
            @"isSection":@(YES)
        },
        @{
            @"title":@"0x01",
            @"detail":@"FFmpeg编译配置和版本信息;OpengGL信息",
            @"class":@"MR0x01ViewController",
        },
        @{
            @"title":@"0x02",
            @"detail":@"查看视频流信息",
            @"class":@"MR0x02ViewController",
        },
        @{
            @"title":@"0x03",
            @"detail":@"读包线程与 AVPacket 缓存队列",
            @"class":@"MR0x03ViewController",
        },
        @{
            @"title":@"0x04",
            @"detail":@"多线程解码",
            @"class":@"MR0x04ViewController",
        },
        @{
            @"title":@"0x05",
            @"detail":@"渲染线程与 AVFrame 缓存队列",
            @"class":@"MR0x05ViewController",
        },
        @{
            @"title":@"0x06",
            @"detail":@"抽取 Decoder 类，封装解码逻辑",
            @"class":@"MR0x06ViewController",
        },
        @{
            @"title":@"二、视频渲染",
            @"isSection":@(YES)
        },
        @{
            @"title":@"0x10",
            @"detail":@"使用 Core Graphics 渲染视频桢",
            @"class":@"MR0x10ViewController",
        },
        @{
            @"title":@"0x11",
            @"detail":@"使用 Core Animation 渲染视频桢",
            @"class":@"MR0x11ViewController",
        },
        @{
            @"title":@"0x13",
            @"detail":@"使用 Core Media 渲染视频桢",
            @"class":@"MR0x13ViewController",
        },
        @{
            @"title":@"0x14",
            @"detail":@"使用 OpenGL 渲染 NV12 视频桢",
            @"class":@"MR0x14ViewController",
        },
        @{
            @"title":@"0x14-1",
            @"detail":@"抽取 OpenGLCompiler 类，封装 OpenGL Shader 相关逻辑",
            @"class":@"MR0x141ViewController",
        },
        @{
            @"title":@"0x14-2",
            @"detail":@"使用 OpenGL 渲染 YUV420P 视频桢",
            @"class":@"MR0x142ViewController",
        },
        @{
            @"title":@"0x14-3",
            @"detail":@"使用 OpenGL 渲染 UYVY422 视频桢",
            @"class":@"MR0x143ViewController",
        },
        @{
            @"title":@"0x14-4",
            @"detail":@"使用 OpenGL 渲染 YUYV422 视频桢",
            @"class":@"MR0x144ViewController",
        },
        @{
            @"title":@"0x14-5",
            @"detail":@"使用 OpenGL 渲染 NV21 视频桢",
            @"class":@"MR0x145ViewController",
        },
        @{
            @"title":@"0x15-1",
            @"detail":@"使用 OpenGL 3.3 渲染 NV12 视频桢",
            @"class":@"MR0x151ViewController",
        },
        @{
            @"title":@"0x15-2",
            @"detail":@"使用 OpenGL 3.3 渲染 YUV420P 视频桢",
            @"class":@"MR0x152ViewController",
        },
        @{
            @"title":@"0x15-3",
            @"detail":@"使用 OpenGL 3.3 渲染 UYVY422 视频桢",
            @"class":@"MR0x153ViewController",
        },
        @{
            @"title":@"0x15-4",
            @"detail":@"使用 OpenGL 3.3 渲染 YUYV422 视频桢",
            @"class":@"MR0x154ViewController",
        },
        @{
            @"title":@"0x15-5",
            @"detail":@"使用 OpenGL 3.3 渲染 NV21 视频桢",
            @"class":@"MR0x155ViewController",
        },
        @{
            @"title":@"0x16",
            @"detail":@"使用 FBO 离屏渲染截图",
            @"class":@"MR0x16ViewController",
        },
        @{
            @"title":@"三、音频渲染",
            @"isSection":@(YES)
        },
        @{
            @"title":@"0x20",
            @"detail":@"使用 AudioUnit 渲染音频桢",
            @"class":@"MR0x20ViewController",
        },
        @{
            @"title":@"0x20-1",
            @"detail":@"使用 AudioQueue 渲染音频桢",
            @"class":@"MR0x201ViewController",
        },
        @{
            @"title":@"0x20-2",
            @"detail":@"抽取 AudioRenderer 类，封装底层音频渲染逻辑",
            @"class":@"MR0x202ViewController",
        },
        @{
            @"title":@"四、封装播放器",
            @"isSection":@(YES)
        },
        @{
            @"title":@"0x30",
            @"detail":@"音视频同步",
            @"class":@"MR0x30ViewController",
        },
        @{
            @"title":@"五、趣味实验",
            @"isSection":@(YES)
        },
        @{
            @"title":@"0x40",
            @"detail":@"雪花屏，灰色色阶图",
            @"class":@"MR0x40ViewController",
        },
        @{
            @"title":@"六、实用工具",
            @"isSection":@(YES)
        },
        @{
            @"title":@"VTP",
            @"detail":@"高效视频抽帧器",
            @"url":@"https://github.com/debugly/MRVideoToPicture",
        }
    ];
    
    [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.dataArr.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return nil;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    RootTableRowView *view = [tableView makeViewWithIdentifier:@"cell" owner:self];
    if (view == nil) {
        view = [[RootTableRowView alloc]init];
        view.identifier = @"cell";
    }
    NSDictionary *dic = self.dataArr[row];
    [view updateTitle:dic[@"title"]];
    [view updateDetail:dic[@"detail"]];
    [view updateArrow:[self tableView:tableView isGroupRow:row]];
    return view;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    NSDictionary *dic = self.dataArr[row];
    return [dic[@"isSection"] boolValue];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    return [self tableView:tableView isGroupRow:row] ? 30 : 35;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    NSDictionary *dic = self.dataArr[row];
    if ([dic[@"isSection"] boolValue]) {
        return NO;
    }
    Class clazz = NSClassFromString(dic[@"class"]);
    if (clazz) {
        NSViewController *vc = [[clazz alloc] init];
        vc.title = dic[@"detail"];
        [self.navigationController pushViewController:vc animated:YES];
    } else {
        NSString * url = dic[@"url"];
        if (url) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tableView deselectRow:row];
    });
    return YES;
}

@end
