//
//  MRUtil.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRUtil : NSObject

+ (NSArray <NSString *>*)videoType;
+ (NSDictionary *)makeBookmarkWithURL:(NSURL *)url;
+ (NSArray <NSDictionary *>*)scanFolderWithPath:(NSString *)dir filter:(NSArray<NSString *>*)types;

@end

NS_ASSUME_NONNULL_END
