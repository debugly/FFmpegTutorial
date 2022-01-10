//
//  FFPlayer0x40.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/10.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"
#import <CoreMedia/CMSampleBuffer.h>

typedef NS_ENUM(NSUInteger, FFPlayer0x40VideoType) {
    FFPlayer0x40VideoSnowType,
    FFPlayer0x40VideoGrayType,
};

NS_ASSUME_NONNULL_BEGIN
@protocol FFPlayer0x40Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CMSampleBufferRef)img;

@end

@interface FFPlayer0x40 : NSObject

@property (nonatomic, weak) id <FFPlayer0x40Delegate> delegate;
@property (nonatomic, assign) FFPlayer0x40VideoType videoType;

- (void)prapareWithSize:(CGSize)size;
- (void)play;
///停止
- (void)stop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
