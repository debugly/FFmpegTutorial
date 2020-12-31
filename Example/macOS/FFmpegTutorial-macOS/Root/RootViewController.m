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
            @"class":@"",
        },
        @{
            @"title":@"0x02",
            @"detail":@"查看视频流信息",
            @"class":@"",
        },
        @{
            @"title":@"0x03",
            @"detail":@"读包线程与 AVPacket 缓存队列",
            @"class":@"",
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
        [self.navigationController pushViewController:vc animated:YES];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [tableView deselectRow:row];
    });
    return YES;
}

@end
