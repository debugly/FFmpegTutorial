//
//  FFTPlayer0x50.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/9/8.
//

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"
#import <CoreMedia/CMSampleBuffer.h>

typedef NS_ENUM(NSUInteger, FFTPlayer0x50VideoType) {
    FFTPlayer0x50VideoSnowType,
    FFTPlayer0x50VideoGrayType,
    FFTPlayer0x50Video3ballType,
};

NS_ASSUME_NONNULL_BEGIN
@protocol FFTPlayer0x50Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CMSampleBufferRef)img;

@end

@interface FFTPlayer0x50 : NSObject

@property (nonatomic, weak) id <FFTPlayer0x50Delegate> delegate;
@property (nonatomic, assign) FFTPlayer0x50VideoType videoType;

- (void)prapareWithSize:(CGSize)size;
- (void)play;
///停止
- (void)asyncStop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
