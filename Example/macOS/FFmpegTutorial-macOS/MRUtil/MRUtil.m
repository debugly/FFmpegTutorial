//
//  MRUtil.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import "MRUtil.h"

@implementation MRUtil

+ (NSArray <NSString *>*)videoType
{
    return @[
        @"wmv",
        @"avi",
        @"rm",
        @"rmvb",
        @"mpg",
        @"mpeg",
        @"3gp",
        @"mov",
        @"mp4",
        @"mkv",
        @"flv",
        @"ts",
        @"webm"
        ];
}

+ (NSDictionary *)makeBookmarkWithURL:(NSURL *)url
{
    NSData *bookmark = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                        | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess includingResourceValuesForKeys:nil relativeToURL:nil error:nil];
    if (bookmark) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        [dic setObject:url forKey:@"url"];
        [dic setObject:bookmark forKey:@"bookmark"];
        return [dic copy];
    }
    return nil;
}

+ (NSArray <NSDictionary *>*)scanFolderWithPath:(NSString *)dir filter:(NSArray<NSString *>*)types
{
    NSError *error = nil;
    NSMutableArray *bookmarkArr = [NSMutableArray arrayWithCapacity:3];
    NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:&error];
    if (!error && contents) {
        for (NSString *c in contents) {
            NSString*item = [dir stringByAppendingPathComponent:c];
            NSURL*item_url = [NSURL fileURLWithPath:item];
            NSString *pathExtension = [[item_url pathExtension] lowercaseString];
            BOOL add = NO;
            if ([types count] > 0) {
                if ([types containsObject:pathExtension]) {
                    add = YES;
                }
            } else {
                add = YES;
            }
            if (add) {
                NSDictionary *dic = [[self class] makeBookmarkWithURL:item_url];
                [bookmarkArr addObject:dic];
            }
        }
        //按照文件名排序
        [bookmarkArr sortUsingComparator:^NSComparisonResult(NSDictionary * obj1, NSDictionary * obj2) {
            NSURL *url1 = obj1[@"url"];
            NSURL *url2 = obj2[@"url"];
            return (NSComparisonResult)[[url1 lastPathComponent] compare:[url2 lastPathComponent] options:NSNumericSearch];
        }];
        
        return [bookmarkArr copy];
    }
    return nil;
}

@end
