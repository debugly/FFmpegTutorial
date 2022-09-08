//
//  FFPlayer0x50.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/9/8.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"
#import <CoreMedia/CMSampleBuffer.h>

typedef NS_ENUM(NSUInteger, FFPlayer0x50VideoType) {
    FFPlayer0x50VideoSnowType,
    FFPlayer0x50VideoGrayType,
    FFPlayer0x50Video3ballType,
};

NS_ASSUME_NONNULL_BEGIN
@protocol FFPlayer0x50Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CMSampleBufferRef)img;

@end

@interface FFPlayer0x50 : NSObject

@property (nonatomic, weak) id <FFPlayer0x50Delegate> delegate;
@property (nonatomic, assign) FFPlayer0x50VideoType videoType;

- (void)prapareWithSize:(CGSize)size;
- (void)play;
///停止
- (void)asyncStop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
