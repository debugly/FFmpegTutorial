//
//  RootViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/11/25.
//

#import "RootViewController.h"
#import "RootCellView.h"
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
    NSTableColumn *column = [[NSTableColumn alloc] init];
    column.title = @"我的FFmpeg学习教程";
    column.editable = NO;
    column.width = CGRectGetWidth(self.view.bounds);
    column.resizingMask = NSTableColumnAutoresizingMask;
//    column.hidden = YES;
//    tableView.gridStyleMask = NSTableViewSolidVerticalGridLineMask;
    tableView.usesAlternatingRowBackgroundColors = NO;
    //隐藏掉列Header
    tableView.headerView = nil;
    //横实线
    //tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    [tableView addTableColumn:column];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowHeight = 40;
    scrollView.contentView.documentView = tableView;
    self.dataArr = @[
        @{
            @"title":@"0x01",
            @"detail":@"编译配置和版本信息",
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
    RootCellView *view = [tableView makeViewWithIdentifier:@"cell" owner:self];
    if (view == nil) {
        view = [[RootCellView alloc]init];
        view.identifier = @"cell";
    }
    NSDictionary *dic = self.dataArr[row];
    [view updateTitle:dic[@"title"]];
    [view updateDetail:dic[@"detail"]];
    return view;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    RootTableRowView *rowView = [[RootTableRowView alloc] init];
    rowView.backgroundColor = [NSColor blueColor];
    return rowView;
}

//- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
//{
//    return 35;
//}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    NSDictionary *dic = self.dataArr[row];
    Class clazz = NSClassFromString(dic[@"class"]);
    if (clazz) {
        NSViewController *vc = [[clazz alloc] init];
        vc.title = dic[@"detail"];
        [self.navigationController pushViewController:vc animated:YES];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tableView deselectRow:row];
    });
    return YES;
}

@end
