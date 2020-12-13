//
//  MR0x40Task.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x40Task : NSObject

@property (nonatomic, assign, readonly) NSTimeInterval cost;
@property (nonatomic, assign, readonly) int frameCount;
@property (nonatomic, assign, readonly) int duration;
@property (nonatomic, copy, readonly) NSString *videoName;
@property (nonatomic, assign, readonly) NSSize dimension;
@property (nonatomic, copy, readonly) NSString *containerFmt;
@property (nonatomic, copy, readonly) NSString *audioFmt;
@property (nonatomic, copy, readonly) NSString *videoFmt;
@property (nonatomic, strong, readonly) NSURL *fileURL;

- (instancetype)initWithURL:(NSURL *)url;
- (void)start:(void(^)(void))completion;
- (NSString *)saveDir;

@end

NS_ASSUME_NONNULL_END
