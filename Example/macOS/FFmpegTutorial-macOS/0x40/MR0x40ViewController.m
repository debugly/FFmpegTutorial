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
#import "MR0x40TextCellView.h"
#import "MR0x40TableHeaderCell.h"
#import "MR0x40IndicatorCellView.h"

static NSString *const kVideoNameIdentifier = @"videoName";
static NSString *const kDimensionIdentifier = @"dimension";
static NSString *const kContainerFmtIdentifier = @"container";
static NSString *const kAudioFmtIdentifier = @"audioFmt";
static NSString *const kVideoFmtIdentifier = @"videoFmt";
static NSString *const kDurationIdentifier = @"duration";
static NSString *const kPicCountIdentifier = @"picCount";
static NSString *const kCostTimeIdentifier = @"costTime";
static NSString *const kTaskStatusIdentifier = @"status";

@interface MR0x40ViewController ()<MRDragViewDelegate,NSTableViewDelegate,NSTableViewDataSource>

@property (weak) IBOutlet MRDragView *dragView;
@property (strong) NSMutableArray *taskArr;
@property (strong) NSArray *executingQueue;
@property (strong) NSTableView *tableView;

@end

@implementation MR0x40ViewController

- (NSTableColumn *)createTableColumn
{
    NSTableColumn *column = [[NSTableColumn alloc] init];
    column.headerCell = [MR0x40TableHeaderCell new];
    column.editable = NO;
    column.resizingMask = NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask;
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
    self.title = @"视频抽帧";
    
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
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"videoName" ascending:YES];
        column.title = @"文件";
        column.identifier = kVideoNameIdentifier;
        column.width = remindWidth * 0.3;
        column.minWidth = 200;
        [tableView addTableColumn:column];
        remindWidth = remindWidth*0.7;
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"containerFmt" ascending:YES];
        column.title = @"支持容器";
        column.identifier = kContainerFmtIdentifier;
        column.width = remindWidth * 0.2;
        column.minWidth = 200;
        [tableView addTableColumn:column];
        remindWidth = remindWidth*0.8;
    }
    
    remindWidth = remindWidth / 6;
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"audioFmt" ascending:YES];
        column.title = @"音频";
        column.identifier = kAudioFmtIdentifier;
        column.width = remindWidth;
        column.minWidth = 50;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"videoFmt" ascending:YES];
        column.title = @"视频";
        column.identifier = kVideoFmtIdentifier;
        column.width = remindWidth;
        column.minWidth = 50;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.title = @"宽高";
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"dimension" ascending:YES comparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            CGSize size1 = [obj1 sizeValue];
            CGSize size2 = [obj2 sizeValue];
            long r = (long)(size1.width * size1.height) - (long)(size2.width * size2.height);
            if (r < 0) {
                return NSOrderedAscending;
            } else if (r > 0){
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];
        column.identifier = kDimensionIdentifier;
        column.width = remindWidth;
        column.minWidth = 80;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"duration" ascending:YES];
        column.title = @"时长";
        column.identifier = kDurationIdentifier;
        column.width = remindWidth;
        column.minWidth = 50;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"frameCount" ascending:YES];
        column.title = @"图片";
        column.identifier = kPicCountIdentifier;
        column.width = remindWidth;
        column.minWidth = 30;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"cost" ascending:YES];
        column.title = @"耗时";
        column.identifier = kCostTimeIdentifier;
        column.width = remindWidth;
        column.minWidth = 30;
        [tableView addTableColumn:column];
    }
    
    {
        NSTableColumn *column = [self createTableColumn];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:@"status" ascending:YES];
        column.title = @"任务状态";
        column.identifier = kTaskStatusIdentifier;
        column.width = remindWidth;
        column.minWidth = 30;
        [tableView addTableColumn:column];
    }
    
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.rowHeight = 35;
    scrollView.contentView.documentView = tableView;
    
    self.tableView = tableView;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.taskArr.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
    if (view == nil) {
        if ([tableColumn.identifier isEqualToString:kTaskStatusIdentifier]) {
            view = [[MR0x40IndicatorCellView alloc]init];
        } else {
            view = [[MR0x40TextCellView alloc]init];
        }
        view.identifier = tableColumn.identifier;
    }
    MR0x40Task *task = self.taskArr[row];
    
    if ([kTaskStatusIdentifier isEqualToString:tableColumn.identifier]) {
        MR0x40IndicatorCellView *indicator = (MR0x40IndicatorCellView *)view;
        if (task.status == MR0x40TaskProcessingStatus) {
            [indicator start];
        } else if (task.status == MR0x40TaskFinishedStatus) {
            [indicator stop];
        } else if (task.status == MR0x40TaskWaitingStatus){
            [indicator waiting];
        } else {
            [indicator wrong];
        }
    } else {
        MR0x40TextCellView *cellView = (MR0x40TextCellView *)view;
        
        if ([kVideoNameIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:task.videoName];
        } else if ([kDimensionIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:NSStringFromSize(task.dimension)];
        } else if ([kContainerFmtIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:task.containerFmt];
        } else if ([kAudioFmtIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:task.audioFmt];
        } else if ([kVideoFmtIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:task.videoFmt];
        } else if ([kDurationIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:[NSString stringWithFormat:@"%ds",task.duration]];
        } else if ([kPicCountIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:[NSString stringWithFormat:@"%d张",task.frameCount]];
        } else if ([kCostTimeIdentifier isEqualToString:tableColumn.identifier]) {
            [cellView updateText:[NSString stringWithFormat:@"%0.2fs",task.cost]];
        }
    }
    return view;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    MR0x40Task *task = self.taskArr[row];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:task.saveDir]];
    return YES;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors
{
    [self.taskArr sortUsingDescriptors:oldDescriptors];
    [tableView reloadData];
}

- (MR0x40Task *)existTaskForUrl:(NSURL *)url
{
    MR0x40Task *t = nil;
    for (MR0x40Task *task in [self.taskArr copy]) {
        if ([[url absoluteString] isEqualToString:[task.fileURL absoluteString]]) {
            t = task;
            break;
        }
    }
    return t;
}

- (void)executeMoreTask
{
    while ([self.executingQueue count] < 3) {
        
        MR0x40Task *firstWaitTask = nil;
        for (MR0x40Task *task in [self.taskArr copy]) {
            if (task.status == MR0x40TaskWaitingStatus) {
                firstWaitTask = task;
                break;
            }
        }
        
        if (firstWaitTask) {
            
            NSMutableArray *executingQueue = [NSMutableArray arrayWithArray:self.executingQueue];
            [executingQueue addObject:firstWaitTask];
            self.executingQueue = executingQueue;
            
            __weakSelf__
            [firstWaitTask start:^(MR0x40Task *task){
                __strongSelf__
                NSUInteger row = [self.taskArr indexOfObject:task];
                [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.tableView.numberOfColumns)]];
                NSMutableArray *executingQueue = [NSMutableArray arrayWithArray:self.executingQueue];
                [executingQueue removeObject:task];
                self.executingQueue = executingQueue;
                [self executeMoreTask];
            }];
        } else {
            break;
        }
    }
    
    [self.tableView reloadData];
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
            
            if ([self existTaskForUrl:url]) {
                continue;
            }
            
            MR0x40Task *task = [[MR0x40Task alloc] initWithURL:url];
            if (!self.taskArr) {
                self.taskArr = [NSMutableArray array];
            }
            [self.taskArr addObject:task];
        }
        
        [self executeMoreTask];
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
