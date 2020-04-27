//
//   FFPlayer0x03.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/27.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface  FFPlayer0x03 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;

///准备
- (void)prepareToPlay;
///读包
- (void)openStream:(void(^)(NSError * _Nullable error,NSString * _Nullable info))completion;

@end

NS_ASSUME_NONNULL_END
