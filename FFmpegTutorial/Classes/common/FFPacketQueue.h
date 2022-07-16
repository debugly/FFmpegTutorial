//
//  FFPacketQueue.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef struct AVPacket AVPacket;
@interface FFPacketQueue : NSObject

- (void)enQueue:(AVPacket *)frame;
- (NSUInteger)count;
//wait forever unless cancel.
- (void)deQueue:(void (^)(AVPacket * _Nullable))block;
- (void)cancel;

@end
NS_ASSUME_NONNULL_END
