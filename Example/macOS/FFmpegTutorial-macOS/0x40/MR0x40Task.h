//
//  MR0x40Task.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MR0x40TaskWaitingStatus,
    MR0x40TaskProcessingStatus,
    MR0x40TaskFinishedStatus,
    MR0x40TaskErrorStatus,
} MR0x40TaskStatus;

@class MR0x40Task;
@interface MR0x40Task : NSObject

@property (nonatomic, assign, readonly) NSTimeInterval cost;
@property (nonatomic, assign, readonly) int frameCount;
@property (nonatomic, assign, readonly) int perferCount;

@property (nonatomic, assign, readonly) int duration;
@property (nonatomic, copy, readonly) NSString *videoName;
@property (nonatomic, assign, readonly) NSSize dimension;
@property (nonatomic, copy, readonly) NSString *containerFmt;
@property (nonatomic, copy, readonly) NSString *audioFmt;
@property (nonatomic, copy, readonly) NSString *videoFmt;
@property (nonatomic, strong, readonly) NSURL *fileURL;
@property (nonatomic, assign, readonly) MR0x40TaskStatus status;

- (instancetype)initWithURL:(NSURL *)url;
- (void)start:(void(^)(MR0x40Task*))completion;
- (void)onReceivedAPicture:(void(^)(MR0x40Task*,NSString *picPath))block;

- (NSString *)saveDir;

@end

NS_ASSUME_NONNULL_END
