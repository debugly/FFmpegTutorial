//
//  MRUtil.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import "MRUtil.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/CGImageDestination.h>
#import <AppKit/NSImage.h>

@implementation MRUtil

+ (NSArray <NSString *>*)videoType
{
    return @[
        @"wmv",
        @"avi",
        @"rm",
        @"rmvb",
        @"mpg",
        @"m2v",
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

+ (CGImageRef)nsImage2cg:(NSImage *)src
{
    NSData * imageData = [src TIFFRepresentation];

    CGImageRef imageRef = NULL;

    if (imageData) {
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData,  NULL);
        imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    }
    return imageRef;
}

+ (BOOL)saveImageToFile:(CGImageRef)img path:(NSString *)imgPath
{
    CFStringRef imageUTType = NULL;
    NSString *fileType = [[imgPath pathExtension] lowercaseString];
    if ([fileType isEqualToString:@"jpg"] || [fileType isEqualToString:@"jpeg"]) {
        imageUTType = kUTTypeJPEG;
    } else if ([fileType isEqualToString:@"png"]) {
        imageUTType = kUTTypePNG;
    } else if ([fileType isEqualToString:@"tiff"]) {
        imageUTType = kUTTypeTIFF;
    } else if ([fileType isEqualToString:@"bmp"]) {
        imageUTType = kUTTypeBMP;
    } else if ([fileType isEqualToString:@"gif"]) {
        imageUTType = kUTTypeGIF;
    } else if ([fileType isEqualToString:@"pdf"]) {
        imageUTType = kUTTypePDF;
    }
    
    if (imageUTType == NULL) {
        imageUTType = kUTTypePNG;
    }

    CFStringRef key = kCGImageDestinationLossyCompressionQuality;
    CFStringRef value = CFSTR("0.5");
    const void * keys[] = {key};
    const void * values[] = {value};
    CFDictionaryRef opts = CFDictionaryCreate(CFAllocatorGetDefault(), keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    NSURL *fileUrl = [NSURL fileURLWithPath:imgPath];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef) fileUrl, imageUTType, 1, opts);
    CFRelease(opts);
    
    if (destination) {
        CGImageDestinationAddImage(destination, img, NULL);
        CGImageDestinationFinalize(destination);
        CFRelease(destination);
        return YES;
    } else {
        return NO;
    }
}


@end
