//
//  FFTAbstractLogger.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2021/7/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
    MRAL_DEBUG_Level,
    MRAL_INFO_Level,
    MRAL_ERROR_Level
} MRALLevel;

@interface FFTAbstractLogger : NSObject

+ (instancetype)sharedLogger;

- (void)write:(MRALLevel)level fmt:(NSString *)fmt,... ;
- (void)registerLogRecipient:(void(^)(MRALLevel,NSString *))block;

@end

#define MRFFLOG_LEVEL_1(level,_fmt,...) [[FFTAbstractLogger sharedLogger] write:level fmt:_fmt,##__VA_ARGS__]
#define MRFFLOG_LEVEL(level,_fmt,...) MRFFLOG_LEVEL_1(level,_fmt,##__VA_ARGS__)

#define MRFF_DEBUG_LOG(_fmt,...)    MRFFLOG_LEVEL(MRAL_DEBUG_Level,_fmt,##__VA_ARGS__)
#define MRFF_INFO_LOG(_fmt,...)     MRFFLOG_LEVEL(MRAL_INFO_Level,_fmt,##__VA_ARGS__)
#define MRFF_ERROR_LOG(_fmt,...)    MRFFLOG_LEVEL(MRAL_ERROR_Level,_fmt,##__VA_ARGS__)

NS_ASSUME_NONNULL_END
