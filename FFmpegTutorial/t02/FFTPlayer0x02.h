//
//  FFTPlayer0x02.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/26.
//

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTPlayer0x02 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;

///准备
- (void)prepareToPlay;
///读包
- (void)openStream:(void(^)(NSError * _Nullable error,NSString * _Nullable info))completion;
///停止读包
- (void)asyncStop;

@end

NS_ASSUME_NONNULL_END
