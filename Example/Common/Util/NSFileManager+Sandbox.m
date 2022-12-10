//
//  NSFileManager+Sandbox.m
//  MRFoundation
//
//  Created by Matt Reach on 2019/11/5.
//

#import "NSFileManager+Sandbox.h"
#import <ImageIO/CGImageDestination.h>
#import <CoreServices/CoreServices.h>

@implementation NSFileManager (Sandbox)

+ (NSError * _Nullable)mr_mkdirP:(NSString *)aDir
{
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:aDir isDirectory:&isDirectory]) {
        if (isDirectory) {
            return nil;
        } else {
            //remove the file
            [[NSFileManager defaultManager] removeItemAtPath:aDir error:NULL];
        }
    }
    //aDir is not exist
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:aDir withIntermediateDirectories:YES attributes:nil error:&err];
    return err;
}

+ (NSError * _Nullable)mr_rm_mkdirP:(NSString *)aDir
{
    [[NSFileManager defaultManager] removeItemAtPath:aDir error:NULL];
    return [self mr_mkdirP:aDir];
}

+ (NSString * _Nullable)mr_DirWithType:(NSSearchPathDirectory)directory
          WithPathComponents:(NSArray<NSString *>*_Nullable)pathArr
{
    NSString *directoryDir = [NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES) firstObject];
    NSString *aDir = directoryDir;
    for (NSString *dir in pathArr) {
        aDir = [aDir stringByAppendingPathComponent:dir];
    }
    if ([self mr_mkdirP:aDir]) {
        return nil;
    }
    return aDir;
}

+ (NSString * _Nullable)mr_DirWithType:(NSSearchPathDirectory)directory
           WithPathComponent:(NSString *_Nullable)path
{
    if (path) {
        return [self mr_DirWithType:directory WithPathComponents:@[path]];
    } else {
        return [self mr_DirWithType:directory WithPathComponents:nil];
    }
}

+ (BOOL)mr_saveImageToFile:(CGImageRef)img path:(NSString *)imgPath
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
