//
//  FFPlayer.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    FFPlayerErrorCode_OpenFileFaild,///文件打开失败
    FFPlayerErrorCode_StreamNotFound///找不到音视频流
} FFPlayerErrorCode;

@interface FFPlayer : NSObject

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
