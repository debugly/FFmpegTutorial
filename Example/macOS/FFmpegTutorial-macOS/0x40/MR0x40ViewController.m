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
#import "MR0x40CellView.h"
#import "MR0x40TableHeaderCell.h"

static NSString *const kVideoNameIdentifier = @"videoName";
static NSString *const kDimensionIdentifier = @"dimension";
static NSString *const kContainerFmtIdentifier = @"container";
static NSString *const kAudioFmtIdentifier = @"audioFmt";
static NSString *const kVideoFmtIdentifier = @"videoFmt";
static NSString *const kDurationIdentifier = @"duration";
static NSString *const kPicCountIdentifier = @"picCount";
static NSString *const kCostTimeIdentifier = @"costTime";

@interface MR0x40ViewController ()<MRDragViewDelegate,NSTableViewDelegate,NSTableViewDataSource>

@property (weak) IBOutlet MRDragView *dragView;
@property (strong) NSMutableArray *taskArr;
@property (strong) NSOperationQueue *queue;
@property (strong) NSTableView *tableView;

@end

@implementation MR0x40ViewController

- (NSTableColumn *)createTableColumn {
    NSTableColumn *column = [[NSTableColumn alloc] init];
    column.headerCell = [MR0x40TableHeaderCell new];
    column.editable = NO;
    return column;
}

//-[NSNib _initWithNibNamed:bundle:options:] could not load the nibName: MR0x40ViewController in bundle (null).
//- (void)loadView
//{
//    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 5;
    
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
    
//    column.hidden = YES;
//    tableView.gridStyleMask = NSTableViewSolidVerticalGridLineMask;
    //交错显示
    tableView.usesAlternatingRowBackgroundColors = YES;
    //隐藏掉列Header
//    tableView.headerView = nil;
    //横实线
    tableView.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    
    CGFloat remindWidth = CGRectGetWidth(self.view.bounds);
    {
        NSTableColumn * column = [self createTableColumn];
        column.title = @"文件";
        column.identifier = kVideoNameIdentifier;
        column.width = remindWidth * 0.3;
        column.minWidth = 200;
        column.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
        [tableView addTableColumn:column];
        remindWidth = remindWidth*0.7;
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"支持容器";
        column.identifier = kContainerFmtIdentifier;
        column.width = remindWidth * 0.2;
        column.minWidth = 200;
        column.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
        [tableView addTableColumn:column];
        remindWidth = remindWidth*0.8;
    }
    
    remindWidth = remindWidth / 6;
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"音频";
        column.identifier = kAudioFmtIdentifier;
        column.width = 50;
        column.resizingMask = NSTableColumnAutoresizingMask;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"视频";
        column.identifier = kVideoFmtIdentifier;
        column.width = 50;
        column.resizingMask = NSTableColumnAutoresizingMask;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"宽高";
        column.identifier = kDimensionIdentifier;
        column.width = 80;
        column.resizingMask = NSTableColumnAutoresizingMask;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"时长";
        column.identifier = kDurationIdentifier;
        column.width = 50;
        column.resizingMask = NSTableColumnAutoresizingMask;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"图片";
        column.identifier = kPicCountIdentifier;
        column.width = remindWidth;
        column.minWidth = 30;
        column.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"耗时";
        column.identifier = kCostTimeIdentifier;
        column.width = remindWidth;
        column.minWidth = 30;
        column.resizingMask = NSTableColumnAutoresizingMask;
        [tableView addTableColumn:column];
    }
    
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowHeight = 40;
    scrollView.contentView.documentView = tableView;
    
    self.tableView = tableView;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.taskArr.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    MR0x40CellView *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if (view == nil) {
        view = [[MR0x40CellView alloc]init];
        view.identifier = tableColumn.identifier;
    }
    MR0x40Task *task = self.taskArr[row];
    
    if ([kVideoNameIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:task.videoName];
    } else if ([kDimensionIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:NSStringFromSize(task.dimension)];
    } else if ([kContainerFmtIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:task.containerFmt];
    } else if ([kAudioFmtIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:task.audioFmt];
    } else if ([kVideoFmtIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:task.videoFmt];
    } else if ([kDurationIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:[NSString stringWithFormat:@"%ds",task.duration]];
    } else if ([kPicCountIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:[NSString stringWithFormat:@"%d张",task.frameCount]];
    } else if ([kCostTimeIdentifier isEqualToString:tableColumn.identifier]) {
        [view updateText:[NSString stringWithFormat:@"%0.2fs",task.cost]];
    }
    return view;
}

//- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
//{
//    RootTableRowView *rowView = [[RootTableRowView alloc] init];
//    rowView.backgroundColor = [NSColor blueColor];
//    return rowView;
//}

//- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
//{
//    return 35;
//}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    return NO;
}

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
            [self.queue addOperationWithBlock:^{
                [task start:^{
                    NSLog(@"%@:%0.2fs,%d,%0.2ffpms;时长:%d秒",task.videoName,task.cost,task.frameCount,1000 * task.cost/task.frameCount,task.duration);
#warning TODO refresh
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self.tableView reloadData];
                    }];
                }];
            }];
        }
        [self.tableView reloadData];
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
