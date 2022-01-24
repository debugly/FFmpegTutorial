//
//  NSFileManager+Sandbox.h
//  MRFoundation
//
//  Created by Matt Reach on 2019/11/5.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface NSFileManager (Sandbox)


/// 创建文件夹，中间文件夹会自动创建
/// @param aDir 文件夹路径
/// @return some err
+ (NSError * _Nullable)mr_mkdirP:(NSString *)aDir;

/// 先删除文件夹，然后再重新创建文件夹，中间文件夹会自动创建
/// @param aDir 文件夹路径
/// @return some err
+ (NSError * _Nullable)mr_rm_mkdirP:(NSString *)aDir;

/// 沙河 目录下创建 path 目录
/// @param directory 对应类型 path 相对于 directory 的目录
/// @return 完整的路径
+ (NSString * _Nullable)mr_DirWithType:(NSSearchPathDirectory)directory
           WithPathComponent:(NSString *_Nullable)path;

/// 沙河目录下创建 [path/path2/...] 目录
/// @param directory 对应类型 pathArr 相对于 NSSearchPathDirectory 的目录数组
/// @return 完整的路径
+ (NSString * _Nullable)mr_DirWithType:(NSSearchPathDirectory)directory
          WithPathComponents:(NSArray<NSString *>*_Nullable)pathArr;

@end
NS_ASSUME_NONNULL_END
