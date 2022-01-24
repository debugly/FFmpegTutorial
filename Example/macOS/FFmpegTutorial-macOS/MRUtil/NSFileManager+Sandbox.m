//
//  NSFileManager+Sandbox.m
//  MRFoundation
//
//  Created by Matt Reach on 2019/11/5.
//

#import "NSFileManager+Sandbox.h"

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

@end
